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
DROP TABLE IF EXISTS flightseu;

CREATE TABLE flightseu USING DELTA AS
WITH Europe(Env) AS (
  SELECT geographyFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))) )
SELECT icao24, callsign, flightperiod, geoTransform(tgeompoint(flight), 3035) AS flight,
  velocity, heading, vertrate, alert, geoaltitude
FROM flights, Europe
WHERE ST_GeometryType(ST_GeomFromEWKB(unhex(asHexEWKB(
    trajectory(tgeompoint(flight)))))) = 'ST_LineString' AND
  eIntersects(flight, Env);

-- The flights over Europe in three dimensions, in the projection: the position reports of a
-- flight that flightspositions keeps, each at the time of the report, with its geometric altitude
DROP TABLE IF EXISTS flightseu3d;

CREATE TABLE flightseu3d USING DELTA AS
WITH Instants AS (
  SELECT f.icao24, f.callsign, p.posts,
    geoTransform(tgeompoint(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
      ST_PointZ(p.lon, p.lat, p.geoaltitude), 4326))), p.posts), 3035) AS inst
  FROM flightseu f, flightspositions p
  WHERE p.icao24 = f.icao24 AND spansetContains(f.flightperiod, p.posts) AND
    p.geoaltitude IS NOT NULL )
SELECT icao24, callsign,
  tgeompointSeq(array_sort(collect_list(struct(posts, inst))).inst) AS trip
FROM Instants
GROUP BY icao24, callsign;

-- The part of these flights over Europe while they fly, above 3,000 meters and at 100 meters
-- per second or more, cut into pieces of ten minutes. Europe is the envelope in the projection,
-- its edges split every degree.
DROP TABLE IF EXISTS airborne3d;

CREATE TABLE airborne3d USING DELTA AS
WITH Europe(Env) AS (
  SELECT geoTransform(segmentize(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))), 1), 3035) ),
Airborne AS (
  SELECT t.icao24, t.callsign, atGeometry(atTime(t.trip, spansetIntersection(
      getTime(atSpan(f.geoaltitude, floatspanFromText('[3000, 15000]'))),
      getTime(atSpan(f.velocity, floatspanFromText('[100, 400]'))))), Env) AS trip
  FROM flightseu3d t, flightseu f, Europe
  WHERE t.icao24 = f.icao24 AND t.callsign = f.callsign AND
    atSpan(f.geoaltitude, floatspanFromText('[3000, 15000]')) IS NOT NULL AND
    atSpan(f.velocity, floatspanFromText('[100, 400]')) IS NOT NULL ),
Pieces AS (
  SELECT icao24, callsign, inline(timeSplit(trip, INTERVAL '10' MINUTE,
    TIMESTAMP '2026-03-01 00:00:00')) AS (tile, piece)
  FROM Airborne
  WHERE trip IS NOT NULL )
SELECT icao24, callsign, tile, piece AS trip
FROM Pieces;

-- The two flights of the dashboard: the pair of aircraft that come the closest to each other in
-- three dimensions over Europe while both fly. The pieces of a flight partition its time, so the
-- nearest approach of two flights is the smallest one of their pieces of the same tile, and two
-- pieces whose nearest approach is within one kilometer have boxes within one kilometer of each
-- other: the pair is the closest of all whenever its distance is below one kilometer.
DROP TABLE IF EXISTS closepair;

CREATE TABLE closepair USING DELTA AS
SELECT a1.icao24 AS icao24_1, a1.callsign AS callsign_1, a2.icao24 AS icao24_2,
  a2.callsign AS callsign_2, nearestApproachDistance(a1.trip, a2.trip) AS distance
FROM airborne3d a1, airborne3d a2
WHERE a1.tile = a2.tile AND a1.icao24 > a2.icao24 AND
  stboxOverlaps(a1.trip, expandSpace(a2.trip, 1000)) AND
  nearestApproachDistance(a1.trip, a2.trip) IS NOT NULL
ORDER BY 5, 1, 2, 3, 4
LIMIT 1;

SELECT * FROM closepair
