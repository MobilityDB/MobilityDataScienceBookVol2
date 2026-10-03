from pyflink.table import EnvironmentSettings, TableEnvironment

# ----------------------------------------------------
# ENVIRONMENT
# ----------------------------------------------------

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# SOURCE: KAFKA (EVENT TIME)
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_name STRING,
    end_station_name STRING,
    start_time STRING,

    event_time AS TO_TIMESTAMP(
        start_time,
        'yyyy-MM-dd''T''HH:mm:ss.SSS'
    ),

    WATERMARK FOR event_time AS
        event_time - INTERVAL '1' SECOND

) WITH (
    'connector' = 'kafka',
    'topic' = 'raw-trips',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'flink-hop-groupv22',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
)
""")

# ----------------------------------------------------
# SINK: UPSERT KAFKA
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trips_hop (
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
    'topic' = 'trips-hop',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# ----------------------------------------------------
# OPTIONAL FILTER
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY VIEW raw_trips_valid AS
SELECT *
FROM raw_trips
WHERE event_time IS NOT NULL
""")

# ----------------------------------------------------
# HOP (SLIDING) WINDOW - EVENT TIME
#
# Window Size = 10 seconds
# Slide = 5 seconds
#
# Example windows:
#
# [00:00:00,00:00:10)
# [00:00:05,00:00:15)
# [00:00:10,00:00:20)
# ...
#
# Each event can belong to multiple windows.
# ----------------------------------------------------

job = t_env.execute_sql("""
INSERT INTO trips_hop
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    HOP(
        TABLE raw_trips_valid,
        DESCRIPTOR(event_time),
        INTERVAL '5' SECOND,
        INTERVAL '10' SECOND
    )
)
GROUP BY
    window_start,
    window_end,
    start_station_name
""")

print("====================================")
print("EVENT-TIME HOP WINDOW RUNNING")
print("Source topic : raw_trips")
print("Sink topic   : trips-hop")
print("Window size  : 10 seconds")
print("Slide        : 5 seconds")
print("====================================")

job.wait()
