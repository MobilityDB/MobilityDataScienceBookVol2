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
# KAFKA SOURCE  –  event-time edition
#
# Changes vs. original proc-time version:
#   1. Added "event_time STRING" field — matches the key the producer emits.
#   2. Derived "rowtime" column with CAST + WATERMARK.
#      WATERMARK allows 5-second out-of-orderness; tune to your data skew.
#   3. Removed proc_time (we no longer need it).
#   4. Topic kept as "raw-trips" (hyphen) — was "raw_trips" in the original.
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE raw_trips (
    start_station_id   STRING,
    start_station_name STRING,
    end_station_name   STRING,
    event_time         STRING,
    rowtime            AS TO_TIMESTAMP(event_time, 'yyyy-MM-dd''T''HH:mm:ss.SSS'),
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
# STATION LOOKUP TABLE  (unchanged)
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TABLE stations (
    normalized_id   STRING,
    name            STRING,
    longitude       STRING,
    latitude        STRING,
    boroname        STRING,
    taxi_zone_name  STRING,
    geom            STRING
) WITH (
    'connector'              = 'filesystem',
    'path'                   = '/mnt/e/Data/NYCBikes/PythonFlink/stations_clean.tsv',
    'format'                 = 'csv',
    'csv.field-delimiter'    = '\t',
    'csv.ignore-parse-errors' = 'true'
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
        WHEN CAST(s.longitude AS DOUBLE) BETWEEN -74.02 AND -73.93
         AND CAST(s.latitude  AS DOUBLE) BETWEEN 40.70  AND 40.88
        THEN 'INSIDE_MANHATTAN_ZONE'
        ELSE 'OUTSIDE_ZONE'
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
  ON t.start_station_id = s.normalized_id
GROUP BY
    window_start,
    window_end,
    CASE
        WHEN CAST(s.longitude AS DOUBLE) BETWEEN -74.02 AND -73.93
         AND CAST(s.latitude  AS DOUBLE) BETWEEN 40.70  AND 40.88
        THEN 'INSIDE_MANHATTAN_ZONE'
        ELSE 'OUTSIDE_ZONE'
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
