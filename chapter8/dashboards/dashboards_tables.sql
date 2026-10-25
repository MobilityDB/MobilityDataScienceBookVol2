/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- The tables of dashboard 2, built once in MobilitySpark from the flights tables of the notebook
-- "8.3 Create tables from scratch-flights-MobilitySpark": the flights over Europe, these flights
-- in three dimensions in the Lambert azimuthal equal-area projection of Europe (EPSG:3035), their
-- airborne parts cut into pieces of ten minutes, and the pair of aircraft that come the closest
-- to each other. They are the tables of flights/flights_dashboards.sql, as Sect. "Dashboard 2:
-- Close Flights" of chapter 8 explains them: a point is built by Sedona and reaches MobilitySpark
-- through its hexadecimal extended WKB, and MEOS projects it with geoTransform, the name
-- under which MobilitySpark registers the transform of MobilityDB, since Spark owns transform.

-- The flights over Europe whose trajectory is a single line, projected to EPSG:3035. The
-- envelope is the area of use of the projection, read as a geography.
DROP TABLE IF EXISTS FlightsEU;

CREATE TABLE FlightsEU USING DELTA AS
WITH Europe(Env) AS (
  SELECT geographyFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))) )
SELECT ICAO24, CallSign, FlightPeriod, geoTransform(tgeompoint(Flight), 3035) AS Flight,
  Velocity, Heading, VertRate, Alert, GeoAltitude
FROM Flights, Europe
WHERE ST_GeometryType(ST_GeomFromEWKB(unhex(asHexEWKB(
    trajectory(tgeompoint(Flight)))))) = 'ST_LineString' AND
  eIntersects(Flight, Env);

-- The flights over Europe in three dimensions, in the projection: the position reports of a
-- flight that FlightsPositions keeps, each at the time of the report, with its geometric altitude
DROP TABLE IF EXISTS FlightsEU3D;

CREATE TABLE FlightsEU3D USING DELTA AS
WITH Instants AS (
  SELECT f.ICAO24, f.CallSign, p.PosTs,
    geoTransform(tgeompoint(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
      ST_PointZ(p.Lon, p.Lat, p.GeoAltitude), 4326))), p.PosTs), 3035) AS Inst
  FROM FlightsEU f, FlightsPositions p
  WHERE p.ICAO24 = f.ICAO24 AND spansetContains(f.FlightPeriod, p.PosTs) AND
    p.GeoAltitude IS NOT NULL )
SELECT ICAO24, CallSign,
  tgeompointSeq(array_sort(collect_list(struct(PosTs, Inst))).Inst) AS Trip
FROM Instants
GROUP BY ICAO24, CallSign;

-- The part of these flights over Europe while they fly, above 3,000 meters and at 100 meters
-- per second or more, cut into pieces of ten minutes. Europe is the envelope in the projection,
-- its edges split every degree.
DROP TABLE IF EXISTS Airborne3D;

CREATE TABLE Airborne3D USING DELTA AS
WITH Europe(Env) AS (
  SELECT geoTransform(segmentize(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))), 1), 3035) ),
Airborne AS (
  SELECT t.ICAO24, t.CallSign, atGeometry(atTime(t.Trip, spansetIntersection(
      getTime(atSpan(f.GeoAltitude, floatspanFromText('[3000, 15000]'))),
      getTime(atSpan(f.Velocity, floatspanFromText('[100, 400]'))))), Env) AS Trip
  FROM FlightsEU3D t, FlightsEU f, Europe
  WHERE t.ICAO24 = f.ICAO24 AND t.CallSign = f.CallSign AND
    atSpan(f.GeoAltitude, floatspanFromText('[3000, 15000]')) IS NOT NULL AND
    atSpan(f.Velocity, floatspanFromText('[100, 400]')) IS NOT NULL ),
Pieces AS (
  SELECT ICAO24, CallSign, inline(timeSplit(Trip, INTERVAL '10' MINUTE,
    TIMESTAMP '2026-03-01 00:00:00')) AS (Tile, Piece)
  FROM Airborne
  WHERE Trip IS NOT NULL )
SELECT ICAO24, CallSign, Tile, Piece AS Trip
FROM Pieces;

-- The two flights of the dashboard: the pair of aircraft that come the closest to each other in
-- three dimensions over Europe while both fly. The pieces of a flight partition its time, so the
-- nearest approach of two flights is the smallest one of their pieces of the same tile, and two
-- pieces whose nearest approach is within one kilometer have boxes within one kilometer of each
-- other: the pair is the closest of all whenever its distance is below one kilometer.
DROP TABLE IF EXISTS ClosePair;

CREATE TABLE ClosePair USING DELTA AS
SELECT a1.ICAO24 AS ICAO24_1, a1.CallSign AS CallSign_1, a2.ICAO24 AS ICAO24_2,
  a2.CallSign AS CallSign_2, nearestApproachDistance(a1.Trip, a2.Trip) AS Distance
FROM Airborne3D a1, Airborne3D a2
WHERE a1.Tile = a2.Tile AND a1.ICAO24 > a2.ICAO24 AND
  stboxOverlaps(a1.Trip, expandSpace(a2.Trip, 1000)) AND
  nearestApproachDistance(a1.Trip, a2.Trip) IS NOT NULL
ORDER BY 5, 1, 2, 3, 4
LIMIT 1;

SELECT * FROM ClosePair
