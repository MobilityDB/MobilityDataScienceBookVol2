from pyflink.table import EnvironmentSettings, TableEnvironment

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# RAW EVENTS FROM FILE
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE raw_trips (
    ride_id STRING,
    rideable_type STRING,
    started_at STRING,
    ended_at STRING,
    start_station_id STRING,
    start_station_name STRING,
    end_station_id STRING,
    end_station_name STRING,
    start_lat DOUBLE,
    start_lng DOUBLE,
    end_lat DOUBLE,
    end_lng DOUBLE,
    member_casual STRING,
    event_time AS TO_TIMESTAMP(started_at, 'yyyy-MM-dd HH:mm:ss'),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'data/citibike/flink/trips',
    'format' = 'csv',
    'csv.field-delimiter' = '\t'
)
""")
# ----------------------------------------------------
# AGGREGATED OUTPUT
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trips_agg (
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
    'topic' = 'trips-agg2',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# ----------------------------------------------------
# 30-SECOND TUMBLE WINDOWS
# ----------------------------------------------------

job = t_env.execute_sql("""
INSERT INTO trips_agg
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    TUMBLE(TABLE raw_trips,
                   DESCRIPTOR(event_time), 
                   INTERVAL '30' SECOND)
)
GROUP BY
    window_start,
    window_end,
    start_station_name
""")

job.wait()
