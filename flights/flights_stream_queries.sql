-- The baseline of the continuous queries of flights_queries.py of chapter 9 in MobilityDB, on
-- the tables that flights_build.sql builds: the trajectory of each aircraft over the envelope
-- of Europe per hour, from the position reports of FlightsPositions; the flights that end at
-- Brussels, a flight being the position reports of an aircraft until a silence of one hour, as
-- the session windows of the stream cut them; the number of aircraft in the air over Europe at
-- each instant of each hour; and the time that each flight spends within 15 km of each holding
-- fix of London Heathrow.
--
--   psql -d flights -f flights_stream_queries.sql      (or: bash run_all.sh flights_stream_queries)
--
-- The rows of the four answers are written into out/flights_stream_queries_q<n>.csv.

\set ON_ERROR_STOP on
SET timezone = 'UTC';

-- The trajectory of each aircraft over the envelope of Europe in each hour, in EPSG:3035
DROP TABLE IF EXISTS HourlyTrips;
CREATE TABLE HourlyTrips(Hour, ICAO24, Instants, Length) AS
WITH Trips AS (
  SELECT date_trunc('hour', PosTs) AS Hour, ICAO24,
    tgeompointSeq(array_agg(tgeompoint(ST_Transform(ST_SetSRID(ST_MakePoint(Lon, Lat), 4326),
      3035), PosTs) ORDER BY PosTs)) AS Trip
  FROM FlightsPositions
  WHERE Lon BETWEEN -35.58 AND 44.83 AND Lat BETWEEN 24.60 AND 84.73
  GROUP BY 1, 2 )
SELECT Hour, ICAO24, numInstants(Trip), length(Trip)
FROM Trips;

SELECT Hour, COUNT(*) AS Aircraft, SUM(Instants) AS Instants,
  round((SUM(Length) / 1000)::numeric, 3) AS Km
FROM HourlyTrips
WHERE Hour = '2026-03-01 08:00:00+00'
GROUP BY Hour;
\copy (SELECT Hour, ICAO24, Instants, Length FROM HourlyTrips ORDER BY 1, 2) TO 'out/flights_stream_queries_q1.csv' CSV HEADER

-- The flights that end at Brussels: the reports of an aircraft, cut by a silence of one hour
-- or more, whose last report lies in the envelope of Brussels
DROP TABLE IF EXISTS BrusselsArrivals;
CREATE TABLE BrusselsArrivals(ICAO24, SessionStart, SessionEnd, Instants, Length) AS
WITH Reports AS (
  SELECT ICAO24, PosTs, Lon, Lat,
    CASE WHEN PosTs - lag(PosTs) OVER (PARTITION BY ICAO24 ORDER BY PosTs)
      < interval '1 hour' THEN 0 ELSE 1 END AS NewSession
  FROM FlightsPositions ),
Sessions AS (
  SELECT *, SUM(NewSession) OVER (PARTITION BY ICAO24 ORDER BY PosTs) AS Session
  FROM Reports ),
Trips AS (
  SELECT ICAO24, MIN(PosTs) AS SessionStart, MAX(PosTs) AS SessionEnd,
    tgeogpointSeq(array_agg(tgeogpoint(ST_SetSRID(ST_MakePoint(Lon, Lat), 4326)::geography,
      PosTs) ORDER BY PosTs)) AS Trip
  FROM Sessions
  GROUP BY ICAO24, Session )
SELECT ICAO24, SessionStart, SessionEnd, numInstants(Trip), length(Trip)
FROM Trips
WHERE ST_Intersects(endValue(Trip), ST_MakeEnvelope(4.25, 50.75, 4.60, 50.95, 4326)::geography);

SELECT COUNT(*) AS Flights, COUNT(DISTINCT ICAO24) AS Aircraft, SUM(Instants) AS Instants,
  round((SUM(Length) / 1000)::numeric, 3) AS Km
FROM BrusselsArrivals;
\copy (SELECT * FROM BrusselsArrivals ORDER BY 1, 2, 3) TO 'out/flights_stream_queries_q2.csv' CSV HEADER

-- The velocity and the call sign of each kept position report, read as the walk reads them from
-- the first state vector that carries the report
DROP TABLE IF EXISTS PositionAttributes;
CREATE TABLE PositionAttributes(ICAO24, PosTs, Velocity, CallSign) AS
SELECT DISTINCT ON (p.ICAO24, p.PosTs) p.ICAO24, p.PosTs, i.Velocity, trim(i.CallSign)
FROM FlightsPositions p
JOIN FlightsInput i ON i.ICAO24 = p.ICAO24 AND i.LastPosUpdateTs = p.PosTs
WHERE i.Geo IS NOT NULL
ORDER BY p.ICAO24, p.PosTs, i.Et;
CREATE INDEX ON PositionAttributes (ICAO24, PosTs);

-- The number of aircraft in the air over the envelope of Europe at each instant of each hour,
-- an aircraft flying while its velocity lies between 50 and 400 m/s
DROP TABLE IF EXISTS AirborneHourly;
CREATE TABLE AirborneHourly(Hour, Aircraft) AS
WITH Trips AS (
  SELECT date_trunc('hour', p.PosTs) AS Hour, p.ICAO24,
    tgeompointSeq(array_agg(tgeompoint(ST_SetSRID(ST_MakePoint(p.Lon, p.Lat), 4326), p.PosTs)
      ORDER BY p.PosTs)) AS Trip,
    tfloatSeq(array_agg(tfloat(a.Velocity, p.PosTs) ORDER BY p.PosTs)
      FILTER (WHERE a.Velocity IS NOT NULL)) AS Speed
  FROM FlightsPositions p JOIN PositionAttributes a USING (ICAO24, PosTs)
  WHERE p.Lon BETWEEN -35.58 AND 44.83 AND p.Lat BETWEEN 24.60 AND 84.73
  GROUP BY 1, 2 ),
Flying AS (
  SELECT Hour, atTime(Trip, getTime(atSpan(Speed, floatspan '[50, 400]'))) AS Trip
  FROM Trips )
SELECT Hour, tCount(Trip)
FROM Flying
WHERE Trip IS NOT NULL
GROUP BY Hour;

SELECT COUNT(*) AS Hours, MAX(maxValue(Aircraft)) AS Peak
FROM AirborneHourly;
\copy (SELECT Hour, numInstants(Aircraft) AS Instants, maxValue(Aircraft) AS Peak, startTimestamp(atValue(Aircraft, maxValue(Aircraft))) AS PeakTime, twAvg(Aircraft) AS Average FROM AirborneHourly ORDER BY 1) TO 'out/flights_stream_queries_q3.csv' CSV HEADER

-- The time that each flight, the reports of an aircraft cut by a silence of one hour or more,
-- spends within 15 km of each holding fix of London Heathrow while it flies between 2,000 and
-- 5,000 meters, the distance measured on the WGS 84 spheroid
DROP TABLE IF EXISTS StreamHolding;
CREATE TABLE StreamHolding(Fix, ICAO24, CallSign, SessionStart, Periods, Length) AS
WITH Reports AS (
  SELECT p.ICAO24, p.PosTs, p.Lon, p.Lat, p.GeoAltitude, a.CallSign,
    CASE WHEN p.PosTs - lag(p.PosTs) OVER (PARTITION BY p.ICAO24 ORDER BY p.PosTs)
      < interval '1 hour' THEN 0 ELSE 1 END AS NewSession
  FROM FlightsPositions p JOIN PositionAttributes a USING (ICAO24, PosTs) ),
Sessions AS (
  SELECT *, SUM(NewSession) OVER (PARTITION BY ICAO24 ORDER BY PosTs) AS Session
  FROM Reports ),
Trips AS (
  SELECT ICAO24, MAX(CallSign) AS CallSign, MIN(PosTs) AS SessionStart,
    tgeogpointSeq(array_agg(tgeogpoint(ST_SetSRID(ST_MakePoint(Lon, Lat), 4326)::geography,
      PosTs) ORDER BY PosTs)) AS Trip,
    tfloatSeq(array_agg(tfloat(GeoAltitude, PosTs) ORDER BY PosTs)
      FILTER (WHERE GeoAltitude IS NOT NULL)) AS Altitude
  FROM Sessions
  GROUP BY ICAO24, Session ),
Band AS (
  SELECT ICAO24, CallSign, SessionStart,
    atTime(Trip, getTime(atSpan(Altitude, floatspan '[2000, 5000]'))) AS Trip
  FROM Trips ),
Fixes(Fix, Geog) AS (
  SELECT Fix, ST_MakePoint(Lon, Lat)::geography
  FROM (VALUES ('Bovingdon', -0.5500, 51.7260), ('Lambourne', 0.1520, 51.6460),
    ('Ockham', -0.4470, 51.3050), ('Biggin Hill', 0.0350, 51.3310)) AS f(Fix, Lon, Lat) ),
Near AS (
  SELECT f.Fix, b.ICAO24, b.CallSign, b.SessionStart,
    atTime(b.Trip, whenTrue(tDwithin(b.Trip, f.Geog, 15000))) AS Trip
  FROM Band b, Fixes f
  WHERE b.Trip IS NOT NULL AND eDwithin(b.Trip, f.Geog, 15000) )
SELECT Fix, ICAO24, CallSign, SessionStart, getTime(Trip), length(Trip)
FROM Near
WHERE Trip IS NOT NULL;

SELECT COUNT(*) AS Passes, COUNT(DISTINCT ICAO24) AS Aircraft,
  COUNT(*) FILTER (WHERE duration(Periods) >= interval '10 minutes') AS Holding10
FROM StreamHolding;
\copy (SELECT Fix, ICAO24, CallSign, SessionStart, Periods, Length FROM StreamHolding ORDER BY 1, 2, 4) TO 'out/flights_stream_queries_q4.csv' CSV HEADER
