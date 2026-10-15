-- The queries of the analysis of the flights over Europe of the chapter Large-Scale Mobility
-- Databases in MobilitySpark, the statements of the notebook 8.4 Queries-flights-MobilitySpark
-- that build its tables, on the Delta tables of the notebook 8.3 Create tables from
-- scratch-flights-MobilitySpark and of dashboards_tables.sql, and on the countries of Natural
-- Earth (1:50m, admin 0), the shapefile that flights/fetch_data.sh downloads, read from
-- /opt/data/flights/countries in the containers of the cluster. Each statement is separated by
-- a semicolon; run_queries.py runs them.

-- The countries whose territory intersects the area of use of EPSG:3035, in the projection
CREATE OR REPLACE TEMPORARY VIEW countriesinput USING shapefile
  OPTIONS (path 'file:///opt/data/flights/countries');
DROP TABLE IF EXISTS countries;
CREATE TABLE countries USING DELTA AS
SELECT trim(TRAILING chr(0) FROM NAME) AS name, ADM0_A3 AS code,
  geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(ST_Transform(
    geometry, 'EPSG:4326', 'EPSG:3035'), 3035))) AS geom
FROM countriesinput
WHERE ST_Intersects(geometry,
  ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73));

-- Query 1: the flights over Europe between 8 and 9 o'clock
DROP TABLE IF EXISTS morningflights;
CREATE TABLE morningflights USING DELTA AS
WITH Europe(Env) AS (
  SELECT geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(ST_Transform(
    ST_Segmentize(ST_SetSRID(
      ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326), 1),
    'EPSG:4326', 'EPSG:3035'), 3035))) ),
TimePeriod(Period) AS (
  SELECT tstzspanFromText('[2026-03-01 08:00:00+00, 2026-03-01 09:00:00+00)') )
SELECT icao24, callsign, atGeometry(atTime(flight, Period), Env) AS trip
FROM flightseu, Europe, TimePeriod
WHERE atGeometry(atTime(flight, Period), Env) IS NOT NULL;

-- Query 2: the flights leaving Brussels, their route and the position where they end
DROP TABLE IF EXISTS brusselsdepartures;
CREATE TABLE brusselsdepartures USING DELTA AS
WITH Brussels(Env) AS (
  SELECT geographyFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(4.25, 50.75, 4.60, 50.95), 4326))) )
SELECT icao24, callsign, trajectory(flight) AS route, endValue(flight) AS destination,
  geoLength(flight) / 1000 AS km
FROM flights, Brussels
WHERE geoIntersects(startValue(flight), Env);

-- Query 3: the flights over each country and the distance they fly there
DROP TABLE IF EXISTS countrytraffic;
CREATE TABLE countrytraffic USING DELTA AS
SELECT c.name, COUNT(*) AS flights,
  SUM(geoLength(tgeogpoint(geoTransform(atGeometry(f.flight, c.geom),
    4326)))) / 1000 AS km
FROM flightseu f, countries c
WHERE eIntersects(f.flight, c.geom)
GROUP BY c.name;

-- Query 4: the number of aircraft flying over Europe at each instant of the day, a flight flying
-- while its velocity lies between 50 and 400 m/s
DROP TABLE IF EXISTS airbornecount;
CREATE TABLE airbornecount USING DELTA AS
WITH Europe(Env) AS (
  SELECT geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(ST_Transform(
    ST_Segmentize(ST_SetSRID(
      ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326), 1),
    'EPSG:4326', 'EPSG:3035'), 3035))) ),
Flying(Trip) AS (
  SELECT atGeometry(atTime(flight,
    getTime(atSpan(velocity, floatspanFromText('[50, 400]')))), Env)
  FROM flightseu, Europe
  WHERE atSpan(velocity, floatspanFromText('[50, 400]')) IS NOT NULL )
SELECT tCount(Trip) AS aircraft
FROM Flying
WHERE Trip IS NOT NULL;

-- Query 5: the part of each flight within 15 km of each holding fix of London Heathrow while it
-- flies between 2,000 and 5,000 meters, the distance measured on the WGS 84 spheroid
DROP TABLE IF EXISTS holding;
CREATE TABLE holding USING DELTA AS
WITH Fixes(Fix, Geog) AS (
  SELECT fix, geographyFromHexEWKB(ST_AsHEXEWKB(
    ST_SetSRID(ST_Point(lon, lat), 4326)))
  FROM VALUES ('Bovingdon', -0.5500, 51.7260), ('Lambourne', 0.1520, 51.6460),
    ('Ockham', -0.4470, 51.3050), ('Biggin Hill', 0.0350, 51.3310)
    AS f(fix, lon, lat) ),
Band(ICAO24, CallSign, Trip) AS (
  SELECT icao24, callsign,
    atTime(flight, getTime(atSpan(geoaltitude, floatspanFromText('[2000, 5000]'))))
  FROM flights
  WHERE atSpan(geoaltitude, floatspanFromText('[2000, 5000]')) IS NOT NULL ),
Near(Fix, ICAO24, CallSign, Trip) AS (
  SELECT f.Fix, b.ICAO24, b.CallSign,
    atTime(b.Trip, whenTrue(tDwithin(b.Trip, f.Geog, 15000.0))) AS Trip
  FROM Band b, Fixes f
  WHERE eDwithin(b.Trip, f.Geog, 15000.0) )
SELECT Fix AS fix, ICAO24 AS icao24, CallSign AS callsign, Trip AS trip
FROM Near
WHERE Trip IS NOT NULL;
