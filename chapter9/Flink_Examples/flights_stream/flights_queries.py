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
  icao24 STRING, pts BIGINT, lon DOUBLE, lat DOUBLE, geoaltitude DOUBLE,
  vertrate DOUBLE, velocity DOUBLE, callsign STRING,
  posts AS TO_TIMESTAMP_LTZ(pts, 3),
  WATERMARK FOR posts AS posts - INTERVAL '30' SECOND
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
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), icao24 STRING, instants INT,
  length DOUBLE, trajectory STRING
) WITH ({KAFKA}, 'topic' = 'hourly-trips', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE BrusselsArrivals (
  icao24 STRING, session_start TIMESTAMP(3), session_end TIMESTAMP(3), instants INT,
  length DOUBLE, origin STRING, route STRING
) WITH ({KAFKA}, 'topic' = 'brussels-arrivals', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE AirborneHourly (
  window_start TIMESTAMP(3), window_end TIMESTAMP(3), instants INT, peak INT,
  peak_time STRING, average DOUBLE, aircraft STRING
) WITH ({KAFKA}, 'topic' = 'airborne-hourly', 'format' = 'json')
""")
t_env.execute_sql(f"""
CREATE TABLE Holding (
  fix STRING, icao24 STRING, callsign STRING, session_start TIMESTAMP(3),
  session_end TIMESTAMP(3), periods STRING, length DOUBLE, trajectory STRING
) WITH ({KAFKA}, 'topic' = 'holding', 'format' = 'json')
""")

# ----------------------------------------------------
# The instant of each position report, a temporal point in WGS84
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Instants AS
SELECT icao24, TRIM(callsign) AS callsign, posts, lon, lat, velocity, geoaltitude,
  CONCAT('Point(', CAST(lon AS STRING), ' ', CAST(lat AS STRING), ')@',
    DATE_FORMAT(posts, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00') AS inst,
  CONCAT('@', DATE_FORMAT(posts, 'yyyy-MM-dd HH:mm:ss.SSS'), '+00') AS ts
FROM Positions
""")

# ----------------------------------------------------
# The four holding fixes of London Heathrow, as geographies
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW Fixes AS
SELECT fix, geographyFromHexEWKB(hex) AS geog
FROM (VALUES
  ('Bovingdon', '0101000020E61000009A9999999999E1BFB0726891EDDC4940'),
  ('Lambourne', '0101000020E6100000DBF97E6ABC74C33FA69BC420B0D24940'),
  ('Ockham', '0101000020E6100000CFF753E3A59BDCBFD7A3703D0AA74940'),
  ('Biggin Hill', '0101000020E6100000EC51B81E85EBA13FEE7C3F355EAA4940')) AS f(fix, hex)
""")

# ----------------------------------------------------
# The part of the trajectory of each aircraft over the envelope of Europe in each hour during
# which its velocity lies between 50 and 400 m/s, stamped with the time of its window
# ----------------------------------------------------
t_env.execute_sql("""
CREATE TEMPORARY VIEW FlyingHourly AS
SELECT window_time AS rowtime, icao24,
  atTime(trip, getTime(atSpan(speed, floatspanFromText('[50, 400]')))) AS flying
FROM (
  SELECT window_start, window_end, window_time, icao24,
    tgeompointSeq(instants(mergeAgg(tgeompointFromText(CONCAT('SRID=4326;', inst)))))
      AS trip,
    tfloatSeq(instants(mergeAgg(tfloatFromText(CONCAT(CAST(velocity AS STRING), ts)))
      FILTER (WHERE velocity IS NOT NULL))) AS speed
  FROM TABLE(TUMBLE(TABLE Instants, DESCRIPTOR(posts), INTERVAL '1' HOUR))
  WHERE lon BETWEEN -35.58 AND 44.83 AND lat BETWEEN 24.60 AND 84.73
  GROUP BY window_start, window_end, window_time, icao24 )
""")

statements = t_env.create_statement_set()

# QUERY 1: the trajectory of each aircraft over the envelope of Europe in each hour
statements.add_insert_sql("""
INSERT INTO HourlyTrips
SELECT window_start, window_end, icao24, numInstants(trip),
  geoLength(geoTransform(trip, 3035)), asHexEWKB(trajectory(trip))
FROM (
  SELECT window_start, window_end, icao24,
    tgeompointSeq(instants(mergeAgg(tgeompointFromText(CONCAT('SRID=4326;', inst)))))
      AS trip
  FROM TABLE(TUMBLE(TABLE Instants, DESCRIPTOR(posts),
    INTERVAL '1' HOUR))
  WHERE lon BETWEEN -35.58 AND 44.83 AND lat BETWEEN 24.60 AND 84.73
  GROUP BY window_start, window_end, icao24 )
""")

# QUERY 2: the flights that end at Brussels, a flight being the reports of an aircraft until a
# silence of one hour
statements.add_insert_sql("""
INSERT INTO BrusselsArrivals
SELECT icao24, window_start, window_end, numInstants(trip), geoLength(trip),
  asHexEWKB(startValue(trip)), asHexEWKB(trajectory(trip))
FROM (
  SELECT icao24, window_start, window_end,
    tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(inst)))) AS trip
  FROM TABLE(SESSION(TABLE Instants PARTITION BY icao24,
    DESCRIPTOR(posts), INTERVAL '1' HOUR))
  GROUP BY icao24, window_start, window_end )
WHERE eIntersects(atTime(trip, endTimestamp(trip)), geography(stboxFromText(
  'SRID=4326;GEODSTBOX X((4.25,50.75),(4.60,50.95))')))
""")

# QUERY 3: the number of aircraft in the air over the envelope of Europe at each instant of
# each hour, an aircraft flying while its velocity lies between 50 and 400 m/s
statements.add_insert_sql("""
INSERT INTO AirborneHourly
SELECT window_start, window_end, numInstants(aircraft), maxValue(aircraft),
  CAST(startTimestamp(atValue(aircraft, maxValue(aircraft))) AS STRING), twAvg(aircraft),
  asText(aircraft)
FROM (
  SELECT window_start, window_end, tCount(flying) AS aircraft
  FROM TABLE(TUMBLE(TABLE FlyingHourly, DESCRIPTOR(rowtime), INTERVAL '1' HOUR))
  WHERE flying IS NOT NULL
  GROUP BY window_start, window_end )
""")

# QUERY 4: the time that each flight, a session of an aircraft closed by a silence of one hour,
# spends within 15 km of each holding fix of London Heathrow while it flies between 2,000 and
# 5,000 meters, the distance measured on the WGS 84 spheroid
statements.add_insert_sql("""
INSERT INTO Holding
SELECT f.fix, b.icao24, b.callsign, b.window_start, b.window_end,
  asText(getTime(atTime(b.band, whenTrue(tDwithin(b.band, f.geog, 15000.0))))),
  geoLength(atTime(b.band, whenTrue(tDwithin(b.band, f.geog, 15000.0)))),
  asHexEWKB(trajectory(atTime(b.band, whenTrue(tDwithin(b.band, f.geog, 15000.0)))))
FROM (
  SELECT icao24, callsign, window_start, window_end,
    atTime(trip, getTime(atSpan(altitude, floatspanFromText('[2000, 5000]')))) AS band
  FROM (
    SELECT icao24, MAX(callsign) AS callsign, window_start, window_end,
      tgeogpointSeq(instants(mergeAgg(tgeogpointFromText(inst)))) AS trip,
      tfloatSeq(instants(mergeAgg(tfloatFromText(CONCAT(CAST(geoaltitude AS STRING), ts)))
        FILTER (WHERE geoaltitude IS NOT NULL))) AS altitude
    FROM TABLE(SESSION(TABLE Instants PARTITION BY icao24,
      DESCRIPTOR(posts), INTERVAL '1' HOUR))
    GROUP BY icao24, window_start, window_end ) ) b, Fixes f
WHERE b.band IS NOT NULL AND eDwithin(b.band, f.geog, 15000.0) AND
  atTime(b.band, whenTrue(tDwithin(b.band, f.geog, 15000.0))) IS NOT NULL
""")

job = statements.execute()
print("Queries job started: topics hourly-trips, brussels-arrivals, airborne-hourly, holding")
job.wait()
print("Queries job finished.")
