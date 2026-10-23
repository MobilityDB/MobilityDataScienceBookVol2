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

# Allow Flink to produce results even when watermarks advance slowly.
# With SPEED=2000 the producer emits ~2000 s of event-time per real second,
# so windows close quickly; adjust if you lower SPEED.
t_env.get_config().set("table.exec.source.idle-timeout", "10000")

# ----------------------------------------------------
# KAFKA SOURCE: the trips replayed by replay_trips.py, with the event time
# derived from start_time and a watermark allowing 5 seconds of disorder
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_id   STRING,
    start_station_name STRING,
    end_station_name   STRING,
    start_time         STRING,
    rowtime            AS TO_TIMESTAMP(start_time, 'yyyy-MM-dd''T''HH:mm:ss.SSS'),
    WATERMARK FOR rowtime AS rowtime - INTERVAL '5' SECOND
) WITH (
    'connector'                     = 'kafka',
    'topic'                         = 'raw-trips',
    'properties.bootstrap.servers'  = 'localhost:9092',
    'properties.group.id'           = 'geofence-group',
    'scan.startup.mode'             = 'earliest-offset',
    'format'                        = 'json'
)
""")

# ----------------------------------------------------
# STATION LOOKUP TABLE: the stations exported by citibike/build.sh
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
# OUTPUT SINK
# Kept identical – window_start / window_end come from
# the HOP TVF and are already TIMESTAMP(3).
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE geofence_counts (
    window_start  TIMESTAMP(3),
    window_end    TIMESTAMP(3),
    zone          STRING,
    total_trips   BIGINT,
    PRIMARY KEY (window_start, window_end, zone) NOT ENFORCED
) WITH (
    'connector'                    = 'upsert-kafka',
    'topic'                        = 'geofence-counts',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format'                   = 'json',
    'value.format'                 = 'json'
)
""")

# ----------------------------------------------------
# GEOSPATIAL SLIDING WINDOW  –  event-time
#
# Key change: DESCRIPTOR now points to "rowtime" (our ROWTIME column)
# instead of proc_time.  All else is identical.
#
# Window sizes are in event time:
#   slide = 5 minutes, size = 10 minutes
# Increase if your dataset is dense; decrease for finer granularity.
# ----------------------------------------------------
job = t_env.execute_sql("""
INSERT INTO geofence_counts
SELECT
    window_start,
    window_end,
    CASE
        WHEN s.longitude BETWEEN -74.02 AND -73.93
         AND s.latitude BETWEEN 40.70  AND 40.88
        THEN 'INSIDE_MANHATTAN_ZONE'
        ELSE 'OUTSIDE_MANHATTAN_ZONE'
    END AS zone,
    COUNT(*) AS total_trips
FROM TABLE(
    HOP(
        TABLE raw_trips,
        DESCRIPTOR(rowtime),        -- <-- event time, not proc_time
        INTERVAL '5' MINUTE,        -- slide step (event time)
        INTERVAL '10' MINUTE        -- window size (event time)
    )
) t
JOIN stations s
  ON t.start_station_id = s.id
GROUP BY
    window_start,
    window_end,
    CASE
        WHEN s.longitude BETWEEN -74.02 AND -73.93
         AND s.latitude BETWEEN 40.70  AND 40.88
        THEN 'INSIDE_MANHATTAN_ZONE'
        ELSE 'OUTSIDE_MANHATTAN_ZONE'
    END
""")

print("Geofence streaming job started (EVENT TIME)")
print("Window size  = 10 minutes  (event time)")
print("Slide        = 5 minutes   (event time)")
print("Bounding box:")
print("  lon: -74.02 .. -73.93")
print("  lat:  40.70 .. 40.88")
print("Watermark out-of-orderness = 5 seconds")
print("Waiting for Kafka events...")
job.wait()
