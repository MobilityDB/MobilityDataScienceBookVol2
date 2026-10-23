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
