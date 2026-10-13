-- The queries of the analysis of the flights over Europe of the chapter Large-Scale Mobility
-- Databases, on the tables that flights_build.sql and flights_dashboards.sql build for March 1,
-- 2026, and on the countries of Natural Earth (1:50m, admin 0). Their answers are those that
-- MobilitySpark reproduces.
--
--   psql -d flights -f flights_queries.sql      (or: bash run_all.sh flights_queries)
--
-- The rows of the three answers are written into out/flights_queries_q<n>.csv.
--
-- The table CountriesInput holds the shapefile ne_50m_admin_0_countries that fetch_data.sh
-- downloads, loaded by build.sh with shp2pgsql in WGS84.

\set ON_ERROR_STOP on
SET timezone = 'UTC';

-------------------------------------------------------------------------------
-- The countries whose territory intersects the area of use of EPSG:3035, in the projection
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS Countries;
CREATE TABLE Countries(Name, Code, Geom) AS
SELECT c.Name, c.ADM0_A3, ST_Transform(c.Geom, 3035)
FROM CountriesInput c, SRID3035 s
WHERE ST_Intersects(c.Geom, s.Env);

-------------------------------------------------------------------------------
-- Query 1: the flights over Europe between 8 and 9 o'clock
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS MorningFlights;
CREATE TABLE MorningFlights(ICAO24, CallSign, Trip) AS
WITH Europe(Env) AS (
  SELECT ST_Transform(ST_Segmentize(Env, 1), 3035) FROM SRID3035 ),
TimePeriod(Period) AS (
  SELECT tstzspan '[2026-03-01 08:00:00+00, 2026-03-01 09:00:00+00)' )
SELECT ICAO24, CallSign, atGeometry(atTime(Flight, Period), Env)
FROM FlightsEU, Europe, TimePeriod
WHERE atGeometry(atTime(Flight, Period), Env) IS NOT NULL;

SELECT COUNT(*) AS Flights, COUNT(DISTINCT ICAO24) AS Aircraft,
  round((SUM(length(Trip)) / 1000)::numeric, 3) AS Km
FROM MorningFlights;
\copy (SELECT ICAO24, CallSign, length(Trip) AS Length FROM MorningFlights ORDER BY 1, 2) TO 'out/flights_queries_q1.csv' CSV HEADER

-------------------------------------------------------------------------------
-- Query 2: the flights leaving Brussels, their route and the position where they end
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS BrusselsDepartures;
CREATE TABLE BrusselsDepartures(ICAO24, CallSign, Route, Destination, Km) AS
WITH Brussels(Env) AS (
  SELECT ST_MakeEnvelope(4.25, 50.75, 4.60, 50.95, 4326)::geography )
SELECT ICAO24, CallSign, trajectory(Flight), endValue(Flight), length(Flight) / 1000
FROM Flights, Brussels
WHERE ST_Intersects(startValue(Flight), Env);

SELECT COUNT(*) AS Flights, COUNT(DISTINCT ICAO24) AS Aircraft,
  round(SUM(Km)::numeric, 3) AS Km
FROM BrusselsDepartures;
\copy (SELECT ICAO24, CallSign, Km, ST_AsText(Destination) AS Destination FROM BrusselsDepartures ORDER BY 1, 2) TO 'out/flights_queries_q2.csv' CSV HEADER

-------------------------------------------------------------------------------
-- Query 3: the flights over each country and the distance they fly there
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS CountryTraffic;
CREATE TABLE CountryTraffic(Name, Flights, Km) AS
SELECT c.Name, COUNT(*),
  SUM(length(transform(atGeometry(f.Flight, c.Geom), 4326)::tgeogpoint)) / 1000
FROM FlightsEU f, Countries c
WHERE eIntersects(f.Flight, c.Geom)
GROUP BY c.Name;

SELECT COUNT(*) AS Countries, SUM(Flights) AS Flights, round(SUM(Km)::numeric, 3) AS Km
FROM CountryTraffic;
SELECT Name, Flights, round(Km::numeric, 3) AS Km
FROM CountryTraffic ORDER BY Km DESC LIMIT 10;
\copy (SELECT Name, Flights, Km FROM CountryTraffic ORDER BY Name) TO 'out/flights_queries_q3.csv' CSV HEADER

-------------------------------------------------------------------------------
-- Query 4: the number of aircraft flying over Europe at each instant of the day, an aircraft
-- flying while its velocity lies between 50 and 400 m/s
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS AirborneCount;
CREATE TABLE AirborneCount(Aircraft) AS
WITH Europe(Env) AS (
  SELECT ST_Transform(ST_Segmentize(Env, 1), 3035) FROM SRID3035 ),
Flying(Trip) AS (
  SELECT atGeometry(atTime(Flight, getTime(atSpan(Velocity, floatspan '[50, 400]'))), Env)
  FROM FlightsEU, Europe
  WHERE atSpan(Velocity, floatspan '[50, 400]') IS NOT NULL )
SELECT tCount(Trip) FROM Flying WHERE Trip IS NOT NULL;

SELECT numInstants(Aircraft) AS Instants, maxValue(Aircraft) AS Peak,
  startTimestamp(atValue(Aircraft, maxValue(Aircraft))) AS PeakTime,
  round(twAvg(Aircraft)::numeric, 3) AS Average
FROM AirborneCount;
\copy (SELECT h AS Hour, valueAtTimestamp(Aircraft, h) AS Aircraft FROM AirborneCount, generate_series(timestamptz '2026-03-01 00:00:00+00', timestamptz '2026-03-01 23:00:00+00', interval '1 hour') AS h ORDER BY h) TO 'out/flights_queries_q4.csv' CSV HEADER

-------------------------------------------------------------------------------
-- Query 5: the time that each flight spends within 15 km of each holding fix of London Heathrow
-- while it flies between 2,000 and 5,000 meters, the distance measured on the WGS 84 spheroid
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS Holding;
CREATE TABLE Holding(Fix, ICAO24, CallSign, Holding, Km) AS
WITH Fixes(Fix, Geog) AS (
  SELECT Fix, ST_MakePoint(Lon, Lat)::geography
  FROM (VALUES ('Bovingdon', -0.5500, 51.7260), ('Lambourne', 0.1520, 51.6460),
    ('Ockham', -0.4470, 51.3050), ('Biggin Hill', 0.0350, 51.3310)) AS f(Fix, Lon, Lat) ),
Band(ICAO24, CallSign, Trip) AS (
  SELECT ICAO24, CallSign,
    atTime(Flight, getTime(atSpan(GeoAltitude, floatspan '[2000, 5000]')))
  FROM Flights
  WHERE atSpan(GeoAltitude, floatspan '[2000, 5000]') IS NOT NULL ),
Near(Fix, ICAO24, CallSign, Trip) AS (
  SELECT f.Fix, b.ICAO24, b.CallSign, atTime(b.Trip, whenTrue(tDwithin(b.Trip, f.Geog, 15000)))
  FROM Band b, Fixes f
  WHERE eDwithin(b.Trip, f.Geog, 15000) )
SELECT Fix, ICAO24, CallSign, duration(Trip), length(Trip) / 1000
FROM Near
WHERE Trip IS NOT NULL;

SELECT Fix, COUNT(*) AS Flights,
  COUNT(*) FILTER (WHERE Holding >= interval '10 minutes') AS Holding10,
  MAX(Holding) AS Longest
FROM Holding GROUP BY Fix ORDER BY Fix;
SELECT Fix, ICAO24, CallSign, Holding, round(Km::numeric, 1) AS Km
FROM Holding WHERE Holding >= interval '10 minutes' ORDER BY Holding DESC LIMIT 10;
\copy (SELECT Fix, ICAO24, CallSign, extract(epoch FROM Holding) AS Seconds, Km FROM Holding ORDER BY 1, 2, 3, 4) TO 'out/flights_queries_q5.csv' CSV HEADER
