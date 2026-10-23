#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

from pyflink.table import EnvironmentSettings, TableEnvironment

# ----------------------------------------------------
# ENV
# ----------------------------------------------------
env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)
t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# SOURCE: raw_trips (Kafka)
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_id STRING,
    start_station_name STRING,
    end_station_name STRING,
    start_time STRING,
    event_time AS TO_TIMESTAMP(start_time, 'yyyy-MM-dd''T''HH:mm:ss.SSS'),
    WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'raw-trips',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'topn-group-v3',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
)
""")

# ----------------------------------------------------
# DIMENSION TABLE: stations (filesystem CSV, header-free)
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE stations (
    id STRING,
    name STRING,
    longitude DOUBLE,
    latitude DOUBLE,
    boroname STRING,
    ntacode STRING,
    ntaname STRING,
    geometry STRING
) WITH (
    'connector' = 'filesystem',
    'path' = 'data/citibike/flink/stations',
    'format' = 'csv',
    'csv.field-delimiter' = '	'
)
""")

# ----------------------------------------------------
# STEP 0: Filter out rows with unparseable / missing event_time
# (json.ignore-parse-errors does NOT protect the windowing
#  operator from null rowtime values - must filter explicitly)
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW raw_trips_valid AS
SELECT *
FROM raw_trips
WHERE event_time IS NOT NULL
  AND start_station_id IS NOT NULL
""")

# ----------------------------------------------------
# STEP 1: Sliding window aggregation on valid trips only
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW station_counts AS
SELECT
    window_start,
    window_end,
    start_station_id,
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
    start_station_id
""")

# ----------------------------------------------------
# STEP 2: Enrich with station name + coordinates AFTER windowing
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW station_counts_named AS
SELECT
    sc.window_start,
    sc.window_end,
    sc.start_station_id,
    s.name AS station_name,
    s.longitude,
    s.latitude,
    sc.total_trips
FROM station_counts sc
JOIN stations s
ON sc.start_station_id = s.id
""")

# ----------------------------------------------------
# SINK (upsert-kafka)
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE top_stations (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    rank_num BIGINT,
    station_id STRING,
    station_name STRING,
    longitude DOUBLE,
    latitude DOUBLE,
    total_trips BIGINT,
    PRIMARY KEY (window_start, window_end, rank_num) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'top-stations-event',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# ----------------------------------------------------
# TOP-N per window
# ----------------------------------------------------
job = t_env.execute_sql("""
INSERT INTO top_stations
SELECT
    window_start,
    window_end,
    rank_num,
    start_station_id,
    station_name,
    longitude,
    latitude,
    total_trips
FROM (
    SELECT
        window_start,
        window_end,
        start_station_id,
        station_name,
        longitude,
        latitude,
        total_trips,
        ROW_NUMBER() OVER (
            PARTITION BY window_start, window_end
            ORDER BY total_trips DESC
        ) AS rank_num
    FROM station_counts_named
)
WHERE rank_num <= 10
""")

print("🏆 Production-grade sliding TOP-N running")
job.wait()
