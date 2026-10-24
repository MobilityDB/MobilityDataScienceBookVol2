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
  ICAO24 STRING, CallSign STRING, Pts BIGINT, Lon DOUBLE, Lat DOUBLE, GeoAltitude DOUBLE,
  PosTs AS TO_TIMESTAMP_LTZ(Pts, 3),
  WATERMARK FOR PosTs AS PosTs - INTERVAL '30' SECOND
) WITH (
  'connector' = 'filesystem', 'path' = '{HERE}/first_example.csv', 'format' = 'csv')
""")

# ----------------------------------------------------
# The trajectory of each aircraft in each window of 30 seconds
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Trips AS
SELECT window_start, window_end, window_time, CallSign,
  tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(
    CONCAT('Point(', CAST(Lon AS STRING), ' ', CAST(Lat AS STRING), ')@',
      DATE_FORMAT(PosTs, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00'))))) AS Trip
FROM TABLE(TUMBLE(TABLE Positions, DESCRIPTOR(PosTs), INTERVAL '30' SECOND))
GROUP BY window_start, window_end, window_time, CallSign
""")

t_env.sql_query("""
SELECT window_start, window_end, CallSign, numInstants(Trip) AS Instants,
  geoLength(Trip) AS Length, asText(Trip) AS Trip
FROM Trips
""").execute().print()

# ----------------------------------------------------
# The number of aircraft with a trajectory at each instant of each window
# ----------------------------------------------------
# The second window adds its own window_start and window_end, which the view drops from Trips
t_env.execute_sql("CREATE TEMPORARY VIEW TripTimes AS SELECT window_time, trip FROM Trips")

t_env.sql_query("""
SELECT window_start, window_end, asText(tCount(Trip)) AS Aircraft
FROM TABLE(TUMBLE(TABLE TripTimes, DESCRIPTOR(window_time), INTERVAL '30' SECOND))
GROUP BY window_start, window_end
""").execute().print()
