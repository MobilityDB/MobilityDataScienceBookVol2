"""The first example of the air traffic stream of chapter 9: the twelve position reports of
IBE06EW and BEL7TC leaving Brussels between 6:09:00 and 6:10:00 UTC on March 1, 2026, in the file
first_example.csv next to this script, are grouped in tumbling windows of 30 seconds, and the
reports of each aircraft in a window are built into its trajectory, a geodetic temporal point,
whose number of instants and length are printed; the trajectories of each window are then counted
at each instant by the temporal aggregate tCount.

The environment is that of flights_queries.py: the module mobilitydb of MobilityFlink is loaded
from the jars of MOBILITYFLINK_JARS, and JMEOS loads libmeos.so from the library path.

    python first_example.py
"""
import os

from pyflink.table import EnvironmentSettings, TableEnvironment

HERE = os.path.dirname(os.path.abspath(__file__))

t_env = TableEnvironment.create(EnvironmentSettings.in_streaming_mode())
config = t_env.get_config()
config.set("pipeline.jars", ";".join(
    "file://" + os.path.abspath(jar) for jar in os.environ["MOBILITYFLINK_JARS"].split(";")))
config.set("parallelism.default", "1")
# The timestamps are written and read in UTC
config.set("table.local-time-zone", "UTC")
t_env.execute_sql("LOAD MODULE mobilitydb")

# ----------------------------------------------------
# SOURCE: twelve position reports, in the order of their times
# ----------------------------------------------------
t_env.execute_sql(f"""
CREATE TEMPORARY TABLE Positions (
  icao24 STRING, callsign STRING, pts BIGINT, lon DOUBLE, lat DOUBLE, geoaltitude DOUBLE,
  posts AS TO_TIMESTAMP_LTZ(pts, 3),
  WATERMARK FOR posts AS posts - INTERVAL '30' SECOND
) WITH (
  'connector' = 'filesystem', 'path' = '{HERE}/first_example.csv', 'format' = 'csv')
""")

# ----------------------------------------------------
# The trajectory of each aircraft in each window of 30 seconds
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Trips AS
SELECT window_start, window_end, window_time, callsign,
  tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(
    CONCAT('Point(', CAST(lon AS STRING), ' ', CAST(lat AS STRING), ')@',
      DATE_FORMAT(posts, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00'))))) AS trip
FROM TABLE(TUMBLE(TABLE Positions, DESCRIPTOR(posts), INTERVAL '30' SECOND))
GROUP BY window_start, window_end, window_time, callsign
""")

t_env.sql_query("""
SELECT window_start, window_end, callsign, numInstants(trip) AS instants,
  geoLength(trip) AS length, asText(trip) AS trip
FROM Trips
""").execute().print()

# ----------------------------------------------------
# The number of aircraft with a trajectory at each instant of each window
# ----------------------------------------------------
# The second window adds its own window_start and window_end, which the view drops from Trips
t_env.execute_sql("CREATE TEMPORARY VIEW TripTimes AS SELECT window_time, trip FROM Trips")

t_env.sql_query("""
SELECT window_start, window_end, asText(tCount(trip)) AS aircraft
FROM TABLE(TUMBLE(TABLE TripTimes, DESCRIPTOR(window_time), INTERVAL '30' SECOND))
GROUP BY window_start, window_end
""").execute().print()
