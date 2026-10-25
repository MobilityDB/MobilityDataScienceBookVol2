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

-- The queries of the analysis of the flights over Europe of the chapter Large-Scale Mobility
-- Databases in MobilitySpark, the statements of the notebook 8.4 Queries-flights-MobilitySpark
-- that build its tables, on the Delta tables of the notebook 8.3 Create tables from
-- scratch-flights-MobilitySpark and of dashboards_tables.sql, and on the countries of Natural
-- Earth (1:50m, admin 0), the shapefile that flights/fetch_data.sh downloads, read from
-- /opt/data/flights/countries in the containers of the cluster. Each statement is separated by
-- a semicolon; run_queries.py runs them.

-- The countries whose territory intersects the area of use of EPSG:3035, in the projection
CREATE OR REPLACE TEMPORARY VIEW CountriesInput USING shapefile
  OPTIONS (path 'file:///opt/data/flights/countries');
DROP TABLE IF EXISTS Countries;
CREATE TABLE Countries USING DELTA AS
SELECT trim(TRAILING chr(0) FROM NAME) AS Name, ADM0_A3 AS Code,
  geoTransform(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(geometry, 4326))),
    3035) AS Geom
FROM CountriesInput
WHERE ST_Intersects(geometry,
  ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73));

-- Query 1: the flights over Europe between 8 and 9 o'clock
DROP TABLE IF EXISTS MorningFlights;
CREATE TABLE MorningFlights USING DELTA AS
WITH Europe(Env) AS (
  SELECT geoTransform(segmentize(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))), 1), 3035) ),
TimePeriod(Period) AS (
  SELECT tstzspanFromText('[2026-03-01 08:00:00+00, 2026-03-01 09:00:00+00)') )
SELECT ICAO24, CallSign, atGeometry(atTime(Flight, Period), Env) AS Trip
FROM FlightsEU, Europe, TimePeriod
WHERE atGeometry(atTime(Flight, Period), Env) IS NOT NULL;

-- Query 2: the flights leaving Brussels, their route and the position where they end
DROP TABLE IF EXISTS BrusselsDepartures;
CREATE TABLE BrusselsDepartures USING DELTA AS
WITH Brussels(Env) AS (
  SELECT geographyFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(4.25, 50.75, 4.60, 50.95), 4326))) )
SELECT ICAO24, CallSign, trajectory(Flight) AS Route, endValue(Flight) AS Destination,
  geoLength(Flight) / 1000 AS Km
FROM Flights, Brussels
WHERE geoIntersects(startValue(Flight), Env);

-- Query 3: the flights over each country and the distance they fly there
DROP TABLE IF EXISTS CountryTraffic;
CREATE TABLE CountryTraffic USING DELTA AS
SELECT c.Name, COUNT(*) AS Flights,
  SUM(geoLength(tgeogpoint(geoTransform(atGeometry(f.Flight, c.Geom),
    4326)))) / 1000 AS Km
FROM FlightsEU f, Countries c
WHERE eIntersects(f.Flight, c.Geom)
GROUP BY c.Name;

-- Query 4: the number of aircraft flying over Europe at each instant of the day, a flight flying
-- while its velocity lies between 50 and 400 m/s
DROP TABLE IF EXISTS AirborneCount;
CREATE TABLE AirborneCount USING DELTA AS
WITH Europe(Env) AS (
  SELECT geoTransform(segmentize(geometryFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(-35.58, 24.60, 44.83, 84.73), 4326))), 1), 3035) ),
Flying(Trip) AS (
  SELECT atGeometry(atTime(Flight,
    getTime(atSpan(Velocity, floatspanFromText('[50, 400]')))), Env)
  FROM FlightsEU, Europe
  WHERE atSpan(Velocity, floatspanFromText('[50, 400]')) IS NOT NULL )
SELECT tCount(Trip) AS Aircraft
FROM Flying
WHERE Trip IS NOT NULL;

-- Query 5: the part of each flight within 15 km of each holding fix of London Heathrow while it
-- flies between 2,000 and 5,000 meters, the distance measured on the WGS 84 spheroid
DROP TABLE IF EXISTS Holding;
CREATE TABLE Holding USING DELTA AS
WITH Fixes(Fix, Geog) AS (
  SELECT Fix, geographyFromHexEWKB(ST_AsHEXEWKB(
    ST_SetSRID(ST_Point(Lon, Lat), 4326)))
  FROM VALUES ('Bovingdon', -0.5500, 51.7260), ('Lambourne', 0.1520, 51.6460),
    ('Ockham', -0.4470, 51.3050), ('Biggin Hill', 0.0350, 51.3310)
    AS f(Fix, Lon, Lat) ),
Band(ICAO24, CallSign, Trip) AS (
  SELECT ICAO24, CallSign,
    atTime(Flight, getTime(atSpan(GeoAltitude, floatspanFromText('[2000, 5000]'))))
  FROM Flights
  WHERE atSpan(GeoAltitude, floatspanFromText('[2000, 5000]')) IS NOT NULL ),
Near(Fix, ICAO24, CallSign, Trip) AS (
  SELECT f.Fix, b.ICAO24, b.CallSign,
    atTime(b.Trip, whenTrue(tDwithin(b.Trip, f.Geog, 15000.0))) AS Trip
  FROM Band b, Fixes f
  WHERE eDwithin(b.Trip, f.Geog, 15000.0) )
SELECT Fix AS Fix, ICAO24 AS ICAO24, CallSign AS CallSign, Trip AS Trip
FROM Near
WHERE Trip IS NOT NULL;
