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

"""The three dashboards of the air traffic use case of chapter 8 as continuous queries of Flink SQL
over MobilityFlink: the positions of the flights climbing over Brussels, as they arrive (topic
climbing-brussels); the pairs of airborne aircraft within one kilometer of each other in three
dimensions, per window of ten minutes (topic close-pairs); and the positions, aircraft, and
average altitude per hour, and those of the cruising flights (topic traffic-per-hour).

The input is the topic flights-positions, the position reports that the job FlightsWalk (in the
directory walk) keeps, read by the table Positions, whose time attribute is the time of the
report and whose watermark lags it by 30 seconds. The functions of MEOS are those of the module
mobilitydb of MobilityFlink, loaded by LOAD MODULE: the jar of MobilityFlink, the jar of JMEOS and
its dependencies are listed in the environment variable MOBILITYFLINK_JARS (separated by ';'),
and JMEOS loads libmeos.so from the directory src of the working directory. The three queries
are those of the section "Use Case: Air Traffic over Europe as a Stream" of the book, run as one
job.

    python flights_dashboards.py            # follows the topic as it grows
    python flights_dashboards.py bounded    # reads the topic up to its current end, then stops
"""
import os
import sys

from pyflink.table import EnvironmentSettings, TableEnvironment

BOUNDED = len(sys.argv) > 1 and sys.argv[1] == "bounded"
KAFKA = "'connector' = 'kafka', 'properties.bootstrap.servers' = 'localhost:9092'"

t_env = TableEnvironment.create(EnvironmentSettings.in_streaming_mode())
config = t_env.get_config()
config.set("pipeline.jars", ";".join(
    "file://" + os.path.abspath(jar) for jar in os.environ["MOBILITYFLINK_JARS"].split(";")))
config.set("parallelism.default", "1")
# The timestamps are written and read in UTC
config.set("table.local-time-zone", "UTC")
t_env.execute_sql("LOAD MODULE mobilitydb")

# ----------------------------------------------------
# KAFKA SOURCE: the position reports kept by the walk
# ----------------------------------------------------
t_env.execute_sql(f"""
CREATE TABLE Positions (
  icao24 STRING, pts BIGINT, lon DOUBLE, lat DOUBLE, geoaltitude DOUBLE,
  vertrate DOUBLE, velocity DOUBLE, callsign STRING,
  posts AS TO_TIMESTAMP_LTZ(pts, 3),
  WATERMARK FOR posts AS posts - INTERVAL '30' SECOND
) WITH (
  {KAFKA}, 'topic' = 'flights-positions', 'properties.group.id' = 'flights-dashboards',
  'scan.startup.mode' = 'earliest-offset', 'format' = 'json'
  {", 'scan.bounded.mode' = 'latest-offset'" if BOUNDED else ""})
""")

# ----------------------------------------------------
# KAFKA SINKS: one topic per dashboard
# ----------------------------------------------------
t_env.execute_sql(f"""
CREATE TABLE ClimbingBrussels (
  icao24 STRING, callsign STRING, posts TIMESTAMP_LTZ(3), lon DOUBLE,
  lat DOUBLE, geoaltitude DOUBLE, vertrate DOUBLE
) WITH ({KAFKA}, 'topic' = 'climbing-brussels', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE ClosePairs (
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), icao24_1 STRING,
  icao24_2 STRING, distance DOUBLE
) WITH ({KAFKA}, 'topic' = 'close-pairs', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE TrafficPerHour (
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), positions BIGINT,
  aircraft BIGINT, altitude DOUBLE, cruisingpositions BIGINT, cruisingaircraft BIGINT
) WITH ({KAFKA}, 'topic' = 'traffic-per-hour', 'format' = 'json')
""")

# ----------------------------------------------------
# DASHBOARD 2: the piece of each airborne aircraft in each window of ten minutes, a linear
# sequence in three dimensions in EPSG:3035
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Pieces AS
SELECT window_start, window_end, icao24,
  tgeompointSeq(instants(mergeAgg(geoTransform(tgeompointFromText(CONCAT(
    'SRID=4326;Point Z(', CAST(lon AS STRING), ' ', CAST(lat AS STRING), ' ',
    CAST(geoaltitude AS STRING), ')@', DATE_FORMAT(posts,
    'yyyy-MM-dd HH:mm:ss.SSS'), '+00')), 3035)))) AS trip
FROM TABLE(TUMBLE(TABLE Positions, DESCRIPTOR(posts),
  INTERVAL '10' MINUTE))
WHERE geoaltitude BETWEEN 3000 AND 15000 AND
  velocity BETWEEN 100 AND 400 AND
  lon BETWEEN -35.58 AND 44.83 AND lat BETWEEN 24.60 AND 84.73
GROUP BY window_start, window_end, icao24
""")

statements = t_env.create_statement_set()

# DASHBOARD 1: the positions of the flights over Brussels below 2,000 meters while they climb
statements.add_insert_sql("""
INSERT INTO ClimbingBrussels
SELECT icao24, TRIM(callsign), posts, lon, lat, geoaltitude, vertrate
FROM Positions
WHERE eIntersects(tgeogpointFromText(CONCAT('Point(', CAST(lon AS STRING), ' ',
    CAST(lat AS STRING), ')@', DATE_FORMAT(posts, 'yyyy-MM-dd HH:mm:ss.SSS'),
    '+00')), geography(stboxFromText(
    'SRID=4326;GEODSTBOX X((4.25,50.75),(4.60,50.95))'))) AND
  vertrate BETWEEN 1 AND 20 AND geoaltitude < 2000
""")

# DASHBOARD 2: the pairs of airborne aircraft within one kilometer of each other in three
# dimensions, per window of ten minutes
statements.add_insert_sql("""
INSERT INTO ClosePairs
SELECT p1.window_start, p1.window_end, p1.icao24 AS icao24_1,
  p2.icao24 AS icao24_2, nearestApproachDistance(p1.trip, p2.trip) AS distance
FROM Pieces p1 JOIN Pieces p2 ON p1.window_start = p2.window_start AND
  p1.window_end = p2.window_end AND p1.icao24 > p2.icao24 AND
  stboxOverlaps(p1.trip, expandSpace(p2.trip, 1000))
WHERE nearestApproachDistance(p1.trip, p2.trip) < 1000
""")

# DASHBOARD 3: positions, aircraft, and average altitude of the flights per hour, and of the
# cruising ones
statements.add_insert_sql("""
INSERT INTO TrafficPerHour
SELECT window_start, window_end, COUNT(*) AS positions,
  COUNT(DISTINCT icao24) AS aircraft, AVG(geoaltitude) AS altitude,
  COUNT(*) FILTER (WHERE spanContains(floatspanFromText('[3000, 8000)'),
    geoaltitude)) AS cruisingpositions,
  COUNT(DISTINCT icao24) FILTER (WHERE spanContains(
    floatspanFromText('[3000, 8000)'), geoaltitude)) AS cruisingaircraft
FROM TABLE(TUMBLE(TABLE Positions, DESCRIPTOR(posts),
  INTERVAL '1' HOUR))
GROUP BY window_start, window_end
""")

job = statements.execute()
print("Dashboards job started: topics climbing-brussels, close-pairs, traffic-per-hour")
job.wait()
print("Dashboards job finished.")
