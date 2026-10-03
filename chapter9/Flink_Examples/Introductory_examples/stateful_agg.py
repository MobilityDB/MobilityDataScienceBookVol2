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
result = t_env.sql_query("""
SELECT
    start_station_name,
    COUNT(*) AS rides
FROM bikes 
GROUP BY start_station_name
""")

result.execute().print()






