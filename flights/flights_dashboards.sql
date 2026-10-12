-- The queries of the three dashboards of chapter 5 of the first volume (air traffic analysis),
-- over Europe, on the flights tables that flights_build.sql builds for March 1, 2026. They are
-- the queries of openSkyDashboards.sql of that chapter, on the tables FlightsInput, FlightsDay
-- and Flights, for the day of the data, in UTC. The region is Europe, in its Lambert azimuthal
-- equal-area projection (EPSG:3035), and the city is Brussels with its airport. The restriction of a temporal float to a span of values
-- is atSpan. The aircraft of dashboard 2 are the pair that ClosePair chooses below. A panel of
-- the book that draws a sample of its rows keeps them all here, so that MobilityDB,
-- MobilitySpark and MobilityFlink answer the same rows; the answers of MobilityDB are those
-- that the other two reproduce.
--
--   psql -d flights -f flights_dashboards.sql

\set ON_ERROR_STOP on
SET timezone = 'UTC';

-------------------------------------------------------------------------------
-- The flights over Europe, in the Lambert azimuthal equal-area projection of Europe
-- (EPSG:3035), whose trajectory is a single line. The envelope is the area of use of the
-- projection.
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS SRID3035;
CREATE TABLE SRID3035(Env) AS
SELECT ST_MakeEnvelope(-35.58, 24.60, 44.83, 84.73, 4326);

DROP TABLE IF EXISTS FlightsEU;
CREATE TABLE FlightsEU(ICAO24, CallSign, FlightPeriod, Flight, Velocity, Heading, VertRate,
  Alert, GeoAltitude) AS
SELECT ICAO24, CallSign, FlightPeriod, transform(Flight::tgeompoint, 3035), Velocity, Heading,
  VertRate, Alert, GeoAltitude
FROM Flights f, SRID3035 s
WHERE ST_GeometryType(trajectory(Flight::tgeompoint)) = 'ST_LineString' AND
  eIntersects(f.Flight, s.Env);

SELECT COUNT(*) AS FlightsEU FROM FlightsEU;

-------------------------------------------------------------------------------
-- DASHBOARD 1
-------------------------------------------------------------------------------

-- Noise Heatmap and Altitude of Flights Leaving Brussels: the positions below 2,000 meters of
-- the flights over Brussels while they climb. Each row gives the altitude, the vertical rate and
-- the position of one flight at the same instant T.

WITH Brussels(BrusselsEnv) AS (
  SELECT ST_MakeEnvelope(4.25, 50.75, 4.60, 50.95, 4326)::geography ),
AscSpan(Span) AS (
  SELECT floatspan '[1,20]' ),
TimePeriod(Period) AS (
  SELECT tstzspan '[2026-03-01 00:00:00, 2026-03-01 23:59:00)' ),
TargetFlight(ICAO24, CallSign, RestFlight, RestGeoAlt, RestVertRate) AS (
  SELECT ICAO24, CallSign, atGeometry(atTime(Flight, Period), BrusselsEnv),
    atTime(GeoAltitude, Period), atTime(VertRate, Period)
  FROM Flights, TimePeriod, Brussels
  WHERE atGeometry(atTime(Flight, Period), BrusselsEnv) IS NOT NULL ),
FlightAscent(ICAO24, CallSign, RestGeoAlt, AscTrip, RestVertRate) AS (
  SELECT ICAO24, CallSign,
    atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))),
    atTime(RestFlight, getTime(atSpan(RestVertRate, Span))),
    atSpan(RestVertRate, Span)
  FROM TargetFlight, AscSpan
  WHERE atSpan(RestVertRate, Span) IS NOT NULL AND
    atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))) IS NOT NULL AND
    atTime(RestFlight, getTime(atSpan(RestVertRate, Span))) IS NOT NULL ),
Instants(ICAO24, CallSign, T) AS (
  SELECT ICAO24, CallSign, unnest(set(timestamps(RestGeoAlt)) +
    set(timestamps(AscTrip)) + set(timestamps(RestVertRate)))
  FROM FlightAscent )
SELECT f.ICAO24, f.CallSign, getValue(atTime(RestGeoAlt, T)) AS GeoAltitude,
  getValue(atTime(RestVertRate, T)) AS VertRate,
  ST_X(getValue(atTime(AscTrip, T))::geometry) AS Lon,
  ST_Y(getValue(atTime(AscTrip, T))::geometry) AS Lat, T
FROM FlightAscent f, Instants i
WHERE f.ICAO24 = i.ICAO24 AND f.CallSign = i.CallSign AND
  getValue(atTime(AscTrip, T)) IS NOT NULL AND
  getValue(atTime(RestGeoAlt, T)) IS NOT NULL AND
  getValue(atTime(RestVertRate, T)) IS NOT NULL AND
  getValue(atTime(RestGeoAlt, T)) < 2000
ORDER BY f.ICAO24, f.CallSign, T;

-------------------------------------------------------------------------------
-- DASHBOARD 2
-------------------------------------------------------------------------------

-- The flights over Europe in three dimensions, in the projection: the position reports of a
-- flight that FlightsPositions keeps, each at the time of the report, with its geometric altitude
DROP TABLE IF EXISTS FlightsEU3D;
CREATE TABLE FlightsEU3D(ICAO24, CallSign, Trip) AS
SELECT f.ICAO24, f.CallSign,
  tgeompointSeq(array_agg(tgeompoint(ST_Transform(ST_SetSRID(
    ST_MakePoint(p.Lon, p.Lat, p.GeoAltitude), 4326), 3035), p.PosTs) ORDER BY p.PosTs))
FROM FlightsEU f, FlightsPositions p
WHERE p.ICAO24 = f.ICAO24 AND p.PosTs <@ f.FlightPeriod AND p.GeoAltitude IS NOT NULL
GROUP BY f.ICAO24, f.CallSign;

-- The part of these flights over Europe while they fly, above 3,000 meters and at 100 meters
-- per second or more, cut into pieces of ten minutes. Europe is the envelope of SRID3035 in the
-- projection, its edges split every degree.
DROP TABLE IF EXISTS Airborne3D;
CREATE TABLE Airborne3D(ICAO24, CallSign, Tile, Trip) AS
WITH Europe(Env) AS (
  SELECT ST_Transform(ST_Segmentize(Env, 1), 3035) FROM SRID3035 ),
Airborne(ICAO24, CallSign, Trip) AS (
  SELECT t.ICAO24, t.CallSign, atGeometry(atTime(t.Trip,
    getTime(atSpan(f.GeoAltitude, floatspan '[3000, 15000]')) *
    getTime(atSpan(f.Velocity, floatspan '[100, 400]'))), Env)
  FROM FlightsEU3D t, FlightsEU f, Europe
  WHERE t.ICAO24 = f.ICAO24 AND t.CallSign = f.CallSign AND
    atSpan(f.GeoAltitude, floatspan '[3000, 15000]') IS NOT NULL AND
    atSpan(f.Velocity, floatspan '[100, 400]') IS NOT NULL )
SELECT ICAO24, CallSign, (Piece).time, (Piece).temp
FROM (
  SELECT ICAO24, CallSign,
    timeSplit(Trip, interval '10 minutes', timestamptz '2026-03-01 00:00:00+00') AS Piece
  FROM Airborne
  WHERE Trip IS NOT NULL ) p;
CREATE INDEX Airborne3D_Trip_idx ON Airborne3D USING gist (Trip);
ANALYZE Airborne3D;

-- The two flights of the dashboard: the pair of aircraft that come the closest to each other in
-- three dimensions over Europe while both fly. The pieces of a flight partition its time, so the
-- nearest approach of two flights is the smallest one of their pieces of the same tile, and two
-- pieces whose nearest approach is within one kilometer have boxes within one kilometer of each
-- other: the pair is the closest of all whenever its distance is below one kilometer.
DROP TABLE IF EXISTS ClosePair;
CREATE TABLE ClosePair(ICAO24_1, CallSign_1, ICAO24_2, CallSign_2, Distance) AS
SELECT a1.ICAO24, a1.CallSign, a2.ICAO24, a2.CallSign,
  nearestApproachDistance(a1.Trip, a2.Trip)
FROM Airborne3D a1, Airborne3D a2
WHERE a1.Tile = a2.Tile AND a1.ICAO24 > a2.ICAO24 AND
  a1.Trip && expandSpace(a2.Trip, 1000)
ORDER BY 5, 1, 2, 3, 4
LIMIT 1;

SELECT * FROM ClosePair;

-- Distance Between Two Planes: the distance in kilometers between the two flights over time, in
-- three dimensions
WITH MinDist AS (
  SELECT s1.Trip <-> s2.Trip AS Distance
  FROM FlightsEU3D s1, FlightsEU3D s2, ClosePair p
  WHERE s1.ICAO24 = p.ICAO24_1 AND s1.CallSign = p.CallSign_1 AND
    s2.ICAO24 = p.ICAO24_2 AND s2.CallSign = p.CallSign_2 AND
    atMin(s1.Trip <-> s2.Trip) IS NOT NULL )
SELECT startTimestamp(unnest(instants(Distance))) AS Time,
  getValue(unnest(instants(Distance))) / 1000 AS Distance
FROM MinDist
ORDER BY Time;

-- Position of Close Flights: the position reports of the two flights that FlightsPositions
-- keeps, each at the time of the report
SELECT p.PosTs AS Time, CASE WHEN p.ICAO24 = c.ICAO24_1 THEN 1 ELSE 2 END AS Aircraft, p.Lat,
  p.Lon
FROM FlightsPositions p, Flights f, ClosePair c
WHERE p.ICAO24 = f.ICAO24 AND p.PosTs <@ f.FlightPeriod AND
  ((f.ICAO24 = c.ICAO24_1 AND f.CallSign = c.CallSign_1) OR
   (f.ICAO24 = c.ICAO24_2 AND f.CallSign = c.CallSign_2))
ORDER BY Aircraft, Time;

-- Geoaltitude vs Time, for each of the two flights
SELECT i.EtTs AS Time, i.GeoAltitude
FROM FlightsInput i, Flights f, ClosePair p
WHERE i.ICAO24 = f.ICAO24 AND i.EtTs <@ f.FlightPeriod AND
  f.ICAO24 = p.ICAO24_1 AND f.CallSign = p.CallSign_1
ORDER BY i.EtTs;

SELECT i.EtTs AS Time, i.GeoAltitude
FROM FlightsInput i, Flights f, ClosePair p
WHERE i.ICAO24 = f.ICAO24 AND i.EtTs <@ f.FlightPeriod AND
  f.ICAO24 = p.ICAO24_2 AND f.CallSign = p.CallSign_2
ORDER BY i.EtTs;

-------------------------------------------------------------------------------
-- DASHBOARD 3
-------------------------------------------------------------------------------

-- GPS Location Over Time: the positions and altitudes of the flights between 8 and 9 o'clock
WITH Time(Period) AS (
  SELECT tstzspan '[2026-03-01 08:00:00, 2026-03-01 09:00:00)' ),
FlightTimeSlice(ICAO24, CallSign, TripTimeSlice, GeoAltitude) AS (
  SELECT ICAO24, CallSign, atTime(Flight, Period), atTime(GeoAltitude, Period)
  FROM Flights, Time
  WHERE atTime(Flight, Period) IS NOT NULL ),
FinalOutput AS (
  SELECT ICAO24, CallSign,
    getValue(unnest(instants(GeoAltitude))) AS Altitude,
    ST_X(getValue(unnest(instants(TripTimeSlice)))::geometry) AS Lon,
    ST_Y(getValue(unnest(instants(TripTimeSlice)))::geometry) AS Lat
  FROM FlightTimeSlice
  WHERE TripTimeSlice IS NOT NULL )
SELECT COUNT(*) AS Positions, COUNT(DISTINCT ICAO24) AS Aircraft, AVG(Altitude) AS Altitude
FROM FinalOutput;

-- Cruising Flights: the positions of the flights between 8 and 9 o'clock while they fly
-- between 3,000 and 8,000 meters
WITH TimeAltitude(Period, AltSpan) AS (
  SELECT tstzspan '[2026-03-01 08:00:00, 2026-03-01 09:00:00)', floatspan '[3000,8000)' ),
FlightTimeSlice(ICAO24, CallSign, TripTimeSlice, AltTimeSlice) AS (
  SELECT ICAO24, CallSign, atTime(Flight, Period), atTime(GeoAltitude, Period)
  FROM Flights, TimeAltitude
  WHERE atTime(Flight, Period) IS NOT NULL ),
FlightTimeSliceCruising(ICAO24, CallSign, CruisingTrip, CruisingAltitude) AS (
  SELECT ICAO24, CallSign,
    atTime(TripTimeSlice, getTime(atSpan(AltTimeSlice, AltSpan))),
    atSpan(AltTimeSlice, AltSpan)
  FROM FlightTimeSlice, TimeAltitude
  WHERE atSpan(AltTimeSlice, AltSpan) IS NOT NULL AND
    atTime(TripTimeSlice, getTime(atSpan(AltTimeSlice, AltSpan))) IS NOT NULL ),
Instants(ICAO24, CallSign, T) AS (
  SELECT ICAO24, CallSign,
    unnest(set(timestamps(CruisingTrip)) + set(timestamps(CruisingAltitude)))
  FROM FlightTimeSliceCruising ),
FinalOutput AS (
  SELECT f.ICAO24, f.CallSign, getValue(atTime(CruisingAltitude, T)) AS Alt,
    ST_X(getValue(atTime(CruisingTrip, T))::geometry) AS Lon,
    ST_Y(getValue(atTime(CruisingTrip, T))::geometry) AS Lat, T
  FROM FlightTimeSliceCruising f, Instants i
  WHERE f.ICAO24 = i.ICAO24 AND f.CallSign = i.CallSign AND
    getValue(atTime(CruisingAltitude, T)) IS NOT NULL AND
    getValue(atTime(CruisingTrip, T)) IS NOT NULL )
SELECT COUNT(*) AS Positions, COUNT(DISTINCT ICAO24) AS Aircraft, AVG(Alt) AS Altitude
FROM FinalOutput;
