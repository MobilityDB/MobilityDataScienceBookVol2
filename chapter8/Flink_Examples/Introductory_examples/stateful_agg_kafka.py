from pyflink.table import EnvironmentSettings, TableEnvironment

# -------------------------------------------------------
# 1. ENV
# -------------------------------------------------------
env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

# -------------------------------------------------------
# 2. FILE SOURCE (TSV with header)
# -------------------------------------------------------
t_env.execute_sql("""
CREATE TABLE trips_file (
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
    end_station_name STRING
) WITH (
    'connector' = 'filesystem',
    'path' = '/mnt/e/Data/NYCBikes/tripsny.tsv',
    'format' = 'csv',
    'csv.field-delimiter' = '\t',
    'csv.ignore-first-line' = 'true'
)
""")

# -------------------------------------------------------
# 3. UPSERT KAFKA SINK (FIX)
# -------------------------------------------------------
t_env.execute_sql("""
CREATE TABLE kafka_output (
    start_station_name STRING,
    total_trips BIGINT,
    PRIMARY KEY (start_station_name) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'trips-agg',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# -------------------------------------------------------
# 4. STREAMING QUERY
# -------------------------------------------------------

job = t_env.execute_sql("""
INSERT INTO kafka_output
SELECT
    start_station_name,
    COUNT(*) AS total_trips
FROM trips_file
GROUP BY start_station_name
""")
# -------------------------------------------------------
# 5. KEEP RUNNING
# -------------------------------------------------------
job.wait()
