from pyflink.table import EnvironmentSettings, TableEnvironment

# ----------------------------------------------------
# ENVIRONMENT
# ----------------------------------------------------

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# KAFKA SOURCE (EVENT TIME)
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_name STRING,
    end_station_name STRING,
    start_time STRING,

    event_time AS TO_TIMESTAMP(start_time, 'yyyy-MM-dd''T''HH:mm:ss.SSS'),

    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'raw_trips',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'cumulate-demo',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
)
""")

# ----------------------------------------------------
# KAFKA SINK
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trips_cumulate (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    start_station_name STRING,
    total_trips BIGINT,

    PRIMARY KEY (
        window_start,
        window_end,
        start_station_name
    ) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'trips-cumulate',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# ----------------------------------------------------
# OPTIONAL: FILTER INVALID TIMESTAMPS
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY VIEW raw_trips_valid AS
SELECT *
FROM raw_trips
WHERE event_time IS NOT NULL
""")

# ----------------------------------------------------
# CUMULATE WINDOW (EVENT TIME)
#
# Step = 5 seconds
# Max window = 20 seconds
#
# Example:
# [00:00,00:05)
# [00:00,00:10)
# [00:00,00:15)
# [00:00,00:20)
# ----------------------------------------------------

result = t_env.execute_sql("""
INSERT INTO trips_cumulate
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    CUMULATE(
        TABLE raw_trips,
        DESCRIPTOR(event_time),
        INTERVAL '5' SECOND,
        INTERVAL '20' SECOND
    )
)
GROUP BY
    window_start,
    window_end,
    start_station_name
""")

print("====================================")
print("EVENT-TIME CUMULATE WINDOW RUNNING")
print("Topic source : raw_trips")
print("Topic sink   : trips_cumulate")
print("Step         : 5 seconds")
print("Max window   : 20 seconds")
print("====================================")

result.wait()
