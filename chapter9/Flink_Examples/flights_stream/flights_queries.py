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

"""Four continuous queries of Flink SQL over MobilityFlink on the position reports of the air
traffic stream of chapter 9, which build temporal values from the stream: the trajectory of
each aircraft over Europe per hour (topic hourly-trips), the flights that end at Brussels, each
a session of an aircraft closed by a silence of one hour (topic brussels-arrivals), the number of
aircraft in the air over Europe at each instant of each hour (topic airborne-hourly), and the time
that each flight spends within 15 km of each holding fix of London Heathrow (topic holding).

The input is the topic flights-positions written by the job FlightsWalk, read by the table
Positions of flights_dashboards.py, whose environment this script shares: the module mobilitydb
of MobilityFlink is loaded from the jars of MOBILITYFLINK_JARS, and JMEOS loads libmeos.so from
the directory src of the working directory.

    python flights_queries.py            # follows the topic as it grows
    python flights_queries.py bounded    # reads the topic up to its current end, then stops
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
  ICAO24 STRING, Pts BIGINT, Lon DOUBLE, Lat DOUBLE, GeoAltitude DOUBLE,
  VertRate DOUBLE, Velocity DOUBLE, CallSign STRING,
  PosTs AS TO_TIMESTAMP_LTZ(Pts, 3),
  WATERMARK FOR PosTs AS PosTs - INTERVAL '30' SECOND
) WITH (
  {KAFKA}, 'topic' = 'flights-positions', 'properties.group.id' = 'flights-queries',
  'scan.startup.mode' = 'earliest-offset', 'format' = 'json'
  {", 'scan.bounded.mode' = 'latest-offset'" if BOUNDED else ""})
""")

# ----------------------------------------------------
# KAFKA SINKS: one topic per query
# ----------------------------------------------------
t_env.execute_sql(f"""
CREATE TABLE HourlyTrips (
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), ICAO24 STRING, Instants INT,
  Length DOUBLE, Trajectory STRING
) WITH ({KAFKA}, 'topic' = 'hourly-trips', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE BrusselsArrivals (
  ICAO24 STRING, SessionStart TIMESTAMP(3), SessionEnd TIMESTAMP(3), Instants INT,
  Length DOUBLE, Origin STRING, Route STRING
) WITH ({KAFKA}, 'topic' = 'brussels-arrivals', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE AirborneHourly (
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), Instants INT, Peak INT,
  PeakTime STRING, Average DOUBLE, Aircraft STRING
) WITH ({KAFKA}, 'topic' = 'airborne-hourly', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE Holding (
  Fix STRING, ICAO24 STRING, CallSign STRING, SessionStart TIMESTAMP(3),
  SessionEnd TIMESTAMP(3), Periods STRING, Length DOUBLE, Trajectory STRING
) WITH ({KAFKA}, 'topic' = 'holding', 'format' = 'json')
""")

# ----------------------------------------------------
# The instant of each position report, a temporal point in WGS84
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Instants AS
SELECT ICAO24, TRIM(CallSign) AS CallSign, PosTs, Lon, Lat, Velocity, GeoAltitude,
  concat('Point(', CAST(Lon AS STRING), ' ', CAST(Lat AS STRING), ')@',
    DATE_FORMAT(PosTs, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00') AS Inst,
  concat('@', DATE_FORMAT(PosTs, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00') AS Ts
FROM Positions
""")

# ----------------------------------------------------
# The four holding fixes of London Heathrow, as geographies
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Fixes AS
SELECT Fix, geographyFromHexEWKB(Hex) AS Geog
FROM (VALUES
  ('Bovingdon', '0101000020E61000009A9999999999E1BFB0726891EDDC4940'),
  ('Lambourne', '0101000020E6100000DBF97E6ABC74C33FA69BC420B0D24940'),
  ('Ockham', '0101000020E6100000CFF753E3A59BDCBFD7A3703D0AA74940'),
  ('Biggin Hill', '0101000020E6100000EC51B81E85EBA13FEE7C3F355EAA4940')) AS f(Fix, Hex)
""")

# ----------------------------------------------------
# The part of the trajectory of each aircraft over the envelope of Europe in each hour during
# which its velocity lies between 50 and 400 m/s, stamped with the time of its window
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW FlyingHourly AS
SELECT window_time AS RowTime, ICAO24,
  atTime(Trip, getTime(atSpan(Speed, floatspanFromText('[50, 400]')))) AS Flying
FROM (
  SELECT window_start, window_end, window_time, ICAO24,
    tgeompointSeq(instants(mergeAgg(tgeompointFromText(concat('SRID=4326;', Inst)))))
      AS Trip,
    tfloatSeq(instants(mergeAgg(tfloatFromText(concat(CAST(Velocity AS STRING), Ts)))
      FILTER (WHERE Velocity IS NOT NULL))) AS Speed
  FROM TABLE(TUMBLE(TABLE Instants, DESCRIPTOR(PosTs), INTERVAL '1' HOUR))
  WHERE Lon BETWEEN -35.58 AND 44.83 AND Lat BETWEEN 24.60 AND 84.73
  GROUP BY window_start, window_end, window_time, ICAO24 )
""")

statements = t_env.create_statement_set()

# QUERY 1: the trajectory of each aircraft over the envelope of Europe in each hour
statements.add_insert_sql("""
INSERT INTO HourlyTrips
SELECT window_start, window_end, ICAO24, numInstants(Trip),
  geoLength(geoTransform(Trip, 3035)), asHexEWKB(trajectory(Trip))
FROM (
  SELECT window_start, window_end, ICAO24,
    tgeompointSeq(instants(mergeAgg(tgeompointFromText(concat('SRID=4326;', Inst)))))
      AS Trip
  FROM TABLE(TUMBLE(TABLE Instants, DESCRIPTOR(PosTs),
    INTERVAL '1' HOUR))
  WHERE Lon BETWEEN -35.58 AND 44.83 AND Lat BETWEEN 24.60 AND 84.73
  GROUP BY window_start, window_end, ICAO24 )
""")

# QUERY 2: the flights that end at Brussels, a flight being the reports of an aircraft until a
# silence of one hour
statements.add_insert_sql("""
INSERT INTO BrusselsArrivals
SELECT ICAO24, window_start, window_end, numInstants(Trip), geoLength(Trip),
  asHexEWKB(startValue(Trip)), asHexEWKB(trajectory(Trip))
FROM (
  SELECT ICAO24, window_start, window_end,
    tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(Inst)))) AS Trip
  FROM TABLE(SESSION(TABLE Instants PARTITION BY ICAO24,
    DESCRIPTOR(PosTs), INTERVAL '1' HOUR))
  GROUP BY ICAO24, window_start, window_end )
WHERE eIntersects(atTime(Trip, endTimestamp(Trip)), geography(stboxFromText(
  'SRID=4326;GEODSTBOX X((4.25,50.75),(4.60,50.95))')))
""")

# QUERY 3: the number of aircraft in the air over the envelope of Europe at each instant of
# each hour, an aircraft flying while its velocity lies between 50 and 400 m/s
statements.add_insert_sql("""
INSERT INTO AirborneHourly
SELECT window_start, window_end, numInstants(Aircraft), maxValue(Aircraft),
  CAST(startTimestamp(atValue(Aircraft, maxValue(Aircraft))) AS STRING), twAvg(Aircraft),
  asText(Aircraft)
FROM (
  SELECT window_start, window_end, tCount(Flying) AS Aircraft
  FROM TABLE(TUMBLE(TABLE FlyingHourly, DESCRIPTOR(RowTime), INTERVAL '1' HOUR))
  WHERE Flying IS NOT NULL
  GROUP BY window_start, window_end )
""")

# QUERY 4: the time that each flight, a session of an aircraft closed by a silence of one hour,
# spends within 15 km of each holding fix of London Heathrow while it flies between 2,000 and
# 5,000 meters, the distance measured on the WGS 84 spheroid
statements.add_insert_sql("""
INSERT INTO Holding
SELECT f.Fix, b.ICAO24, b.CallSign, b.window_start, b.window_end,
  asText(getTime(atTime(b.Band, whenTrue(tDwithin(b.Band, f.Geog, 15000.0))))),
  geoLength(atTime(b.Band, whenTrue(tDwithin(b.Band, f.Geog, 15000.0)))),
  asHexEWKB(trajectory(atTime(b.Band, whenTrue(tDwithin(b.Band, f.Geog, 15000.0)))))
FROM (
  SELECT ICAO24, CallSign, window_start, window_end,
    atTime(Trip, getTime(atSpan(Altitude, floatspanFromText('[2000, 5000]')))) AS Band
  FROM (
    SELECT ICAO24, MAX(CallSign) AS CallSign, window_start, window_end,
      tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(Inst)))) AS Trip,
      tfloatSeq(instants(mergeAgg(tfloatFromText(concat(CAST(GeoAltitude AS STRING), Ts)))
        FILTER (WHERE GeoAltitude IS NOT NULL))) AS Altitude
    FROM TABLE(SESSION(TABLE Instants PARTITION BY ICAO24,
      DESCRIPTOR(PosTs), INTERVAL '1' HOUR))
    GROUP BY ICAO24, window_start, window_end ) ) b, Fixes f
WHERE b.Band IS NOT NULL AND eDwithin(b.Band, f.Geog, 15000.0) AND
  atTime(b.Band, whenTrue(tDwithin(b.Band, f.Geog, 15000.0))) IS NOT NULL
""")

job = statements.execute()
print("Queries job started: topics hourly-trips, brussels-arrivals, airborne-hourly, holding")
job.wait()
print("Queries job finished.")
