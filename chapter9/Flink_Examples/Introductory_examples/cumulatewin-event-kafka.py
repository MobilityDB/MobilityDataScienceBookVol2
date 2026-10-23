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
# ENVIRONMENT
# ----------------------------------------------------

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# ----------------------------------------------------
# KAFKA SOURCE (EVENT TIME)
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_name STRING,
    end_station_name STRING,
    start_time STRING,

    event_time AS TO_TIMESTAMP(start_time, 'yyyy-MM-dd''T''HH:mm:ss.SSS'),

    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'raw-trips',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'cumulate-demo',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
)
""")

# ----------------------------------------------------
# KAFKA SINK
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trips_cumulate (
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
    'topic' = 'trips-cumulate',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
)
""")

# ----------------------------------------------------
# OPTIONAL: FILTER INVALID TIMESTAMPS
# ----------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY VIEW raw_trips_valid AS
SELECT *
FROM raw_trips
WHERE event_time IS NOT NULL
""")

# ----------------------------------------------------
# CUMULATE WINDOW (EVENT TIME)
#
# Step = 5 seconds
# Max window = 20 seconds
#
# Example:
# [00:00,00:05)
# [00:00,00:10)
# [00:00,00:15)
# [00:00,00:20)
# ----------------------------------------------------

result = t_env.execute_sql("""
INSERT INTO trips_cumulate
SELECT
    window_start,
    window_end,
    start_station_name,
    COUNT(*) AS total_trips
FROM TABLE(
    CUMULATE(
        TABLE raw_trips,
        DESCRIPTOR(event_time),
        INTERVAL '5' SECOND,
        INTERVAL '20' SECOND
    )
)
GROUP BY
    window_start,
    window_end,
    start_station_name
""")

print("====================================")
print("EVENT-TIME CUMULATE WINDOW RUNNING")
print("Topic source : raw_trips")
print("Topic sink   : trips_cumulate")
print("Step         : 5 seconds")
print("Max window   : 20 seconds")
print("====================================")

result.wait()
