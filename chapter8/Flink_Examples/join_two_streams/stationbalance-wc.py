from pyflink.table import EnvironmentSettings
from pyflink.table import TableEnvironment

env_settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(env_settings)

t_env.get_config().set("parallelism.default", "1")

# --------------------------------------------------
# STARTS
# --------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trip_starts (

    station    STRING,
    lat        DOUBLE,
    lon        DOUBLE,
    event_time STRING,

    rowtime AS TO_TIMESTAMP(
        event_time,
        'yyyy-MM-dd''T''HH:mm:ss.SSS'
    ),

    WATERMARK FOR rowtime AS
        rowtime - INTERVAL '1' SECOND

) WITH (
    'connector'='kafka',
    'topic'='trip-starts',
    'properties.bootstrap.servers'='localhost:9092',
    'properties.group.id'='join-demo-starts',
    'scan.startup.mode'='earliest-offset',
    'format'='json'
)
""")

# --------------------------------------------------
# ENDS
# --------------------------------------------------

t_env.execute_sql("""
CREATE TABLE trip_ends (

    station    STRING,
    lat        DOUBLE,
    lon        DOUBLE,
    event_time STRING,

    rowtime AS TO_TIMESTAMP(
        event_time,
        'yyyy-MM-dd''T''HH:mm:ss.SSS'
    ),

    WATERMARK FOR rowtime AS
        rowtime - INTERVAL '1' SECOND

) WITH (
    'connector'='kafka',
    'topic'='trip-ends',
    'properties.bootstrap.servers'='localhost:9092',
    'properties.group.id'='join-demo-ends',
    'scan.startup.mode'='earliest-offset',
    'format'='json'
)
""")

# --------------------------------------------------
# HOP STARTS
# --------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY VIEW starts_hop AS
SELECT
    window_start,
    window_end,
    station,
    MAX(lat) AS lat,
    MAX(lon) AS lon,
    COUNT(*) AS departures
FROM TABLE(
    HOP(
        TABLE trip_starts,
        DESCRIPTOR(rowtime),
        INTERVAL '30' SECOND,
        INTERVAL '1' MINUTE
    )
)
GROUP BY
    window_start,
    window_end,
    station
""")

# --------------------------------------------------
# HOP ENDS
# --------------------------------------------------

t_env.execute_sql("""
CREATE TEMPORARY VIEW ends_hop AS
SELECT
    window_start,
    window_end,
    station,
    MAX(lat) AS lat,
    MAX(lon) AS lon,
    COUNT(*) AS arrivals
FROM TABLE(
    HOP(
        TABLE trip_ends,
        DESCRIPTOR(rowtime),
        INTERVAL '30' SECOND,
        INTERVAL '1' MINUTE
    )
)
GROUP BY
    window_start,
    window_end,
    station
""")

# --------------------------------------------------
# SINK
# --------------------------------------------------

t_env.execute_sql("""
CREATE TABLE station_balance (

    window_start TIMESTAMP(3),
    window_end   TIMESTAMP(3),

    station      STRING,
    lat          DOUBLE,
    lon          DOUBLE,

    departures   BIGINT,
    arrivals     BIGINT,

    PRIMARY KEY (
        window_start,
        window_end,
        station
    ) NOT ENFORCED

) WITH (
    'connector'='upsert-kafka',
    'topic'='station-balance',
    'properties.bootstrap.servers'='localhost:9092',
    'key.format'='json',
    'value.format'='json'
)
""")

# --------------------------------------------------
# JOIN
# --------------------------------------------------

job = t_env.execute_sql("""
INSERT INTO station_balance

SELECT
    s.window_start,
    s.window_end,
    s.station,
    s.lat,
    s.lon,
    s.departures,
    e.arrivals

FROM starts_hop s

JOIN ends_hop e

ON  s.station      = e.station
AND s.window_start = e.window_start
AND s.window_end   = e.window_end
""")

print("Sliding Window Join Running")

job.wait()
