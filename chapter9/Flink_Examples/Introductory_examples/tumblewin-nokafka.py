from pyflink.table import EnvironmentSettings, TableEnvironment

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# RAW EVENTS FROM KAFKA
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE raw_trips (
    id STRING,
    trip_duration STRING,
    start_time STRING,
    stop_time STRING,
    start_station_id STRING,
    end_station_id STRING,
    bike_id STRING,
    user_type STRING,
    birth_year STRING,
    gender STRING,
    ride_id STRING,
    rideable_type STRING,
    start_latitude STRING,
    start_longitude STRING,
    end_latitude STRING,
    end_longitude STRING,
    start_station_name STRING,
    end_station_name STRING,
    event_time AS TO_TIMESTAMP(start_time, 'yyyy-MM-dd HH:mm:ss[.SSS]'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'raw-trips',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'flink-consumer',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
)
""")
# ----------------------------------------------------
# AGGREGATED OUTPUT
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trips_agg (
    window_start TIMESTAMP(3),
    window_end   TIMESTAMP(3),
    start_station_name STRING,
    total_trips  BIGINT
) WITH (
    'connector' = 'kafka',
    'topic' = 'trips-agg2',
    'properties.bootstrap.servers' = 'localhost:9092',
    'format' = 'json'
)
""")
# ----------------------------------------------------
# 10 SECOND WINDOWS
# ----------------------------------------------------

# Temporarily replace the INSERT INTO trips_agg with this
result = t_env.execute_sql("""
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    TUMBLE(TABLE raw_trips, DESCRIPTOR(event_time), INTERVAL '1' HOUR)
)
GROUP BY window_start, window_end, start_station_name
""")

# Print results to console instead of Kafka
for row in result.collect():
    print(row)
