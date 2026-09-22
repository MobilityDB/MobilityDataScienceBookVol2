from pyflink.table import EnvironmentSettings, TableEnvironment

# --------------------------------------------------
# TABLE ENVIRONMENT
# --------------------------------------------------

t_env = TableEnvironment.create(
    EnvironmentSettings.in_streaming_mode()
)

# --------------------------------------------------
# SOURCE TABLE
# --------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY TABLE bikes (
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
)
WITH (
    'connector' = 'filesystem',
    'path' = '/mnt/e/Data/NYCBikes/tripsny_short.tsv',
    'format' = 'csv',
    'csv.field-delimiter' = '\t',
    'csv.ignore-parse-errors' = 'true'
)
""")
result = t_env.sql_query("""
SELECT
    start_station_name,
    COUNT(*) AS rides
FROM bikes 
WHERE start_time <> 'start_time'
GROUP BY start_station_name
""")

result.execute().print()






