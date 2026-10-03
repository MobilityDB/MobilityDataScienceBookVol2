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
    member_casual STRING
) WITH (
    'connector' = 'filesystem',
    'path' = 'data/citibike/flink/trips',
    'format' = 'csv',
    'csv.field-delimiter' = '\t'
)
""")

# -------------------------------------------------------
# 3. UPSERT KAFKA SINK
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
