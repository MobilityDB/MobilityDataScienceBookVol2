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
    trip_duration BIGINT,
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
    start_latitude DOUBLE,
    start_longitude DOUBLE,
    end_latitude DOUBLE,
    end_longitude DOUBLE,
    start_station_name STRING,
    end_station_name STRING,
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'filesystem',
    'path' = '/mnt/e/Data/NYCBikes/tripsny.tsv',
    'format' = 'csv',
    'csv.field-delimiter' = '\t',
    'csv.ignore-parse-errors' = 'true'
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
# 10 SECOND WINDOWS
# ----------------------------------------------------

job = t_env.execute_sql("""
INSERT INTO trips_agg
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    TUMBLE(
        TABLE raw_trips,
        DESCRIPTOR(proc_time),
        INTERVAL '10' SECOND
    )
)
GROUP BY
    window_start,
    window_end,
    start_station_name
""")

job.wait()
