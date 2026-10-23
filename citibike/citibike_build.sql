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

-- The Citi Bike tables of the book: trips, nta, stations, station_duplicates and boroughs,
-- as Delta tables, by the statements of Sect. "The Citi Bike Data" of the chapter on Apache
-- Spark and Apache Sedona. The directory of the data is the variable data, set by build.sh.

CREATE OR REPLACE TEMP VIEW citibike_csv
USING csv
OPTIONS (path 'file://${data}/citibike/csv', header 'true', inferSchema 'true');

DROP TABLE IF EXISTS trips;
CREATE TABLE trips
USING DELTA
AS
SELECT *
FROM citibike_csv
WHERE start_lng IS NOT NULL AND start_lat IS NOT NULL
   AND end_lng IS NOT NULL AND end_lat IS NOT NULL;

ALTER TABLE trips ADD COLUMN origin GEOMETRY;
ALTER TABLE trips ADD COLUMN target GEOMETRY;
ALTER TABLE trips ADD COLUMN duration_ms BIGINT;

UPDATE trips SET
  origin = st_setsrid(st_point(start_lng, start_lat), 4326),
  target = st_setsrid(st_point(end_lng, end_lat), 4326),
  duration_ms = (unix_timestamp(ended_at) - unix_timestamp(started_at)) * 1000,
  start_station_id = CASE WHEN start_station_id RLIKE '^[0-9]+[.][0-9]$'
    THEN concat(start_station_id, '0') ELSE start_station_id END,
  end_station_id = CASE WHEN end_station_id RLIKE '^[0-9]+[.][0-9]$'
    THEN concat(end_station_id, '0') ELSE end_station_id END;

CREATE OR REPLACE TEMP VIEW auxi_nta_2020 USING shapefile
OPTIONS (path 'file://${data}/citibike/nynta2020_26b', header 'true', inferSchema 'true');

DROP TABLE IF EXISTS nta;
CREATE TABLE nta
USING DELTA
AS SELECT * FROM auxi_nta_2020;

UPDATE nta SET geometry =
  ST_Transform(ST_SetSRID(geometry, 2263), 'EPSG:4326');

DROP TABLE IF EXISTS stations;
CREATE TABLE stations (
  id STRING, name STRING, latitude DOUBLE, longitude DOUBLE,
  geometry GEOMETRY, boroname STRING, ntacode STRING, ntaname STRING
) USING DELTA;

-- One record per station identifier, with its number of trips
CREATE OR REPLACE TEMP VIEW stations_clean AS
WITH trip_starts AS (
  SELECT
    TRIM(CAST(start_station_id AS STRING)) AS id, start_station_name AS name,
    start_lat AS latitude, start_lng AS longitude
  FROM trips
  WHERE start_station_id IS NOT NULL
  UNION ALL
  SELECT
    TRIM(CAST(end_station_id AS STRING)) AS id, end_station_name AS name,
    end_lat AS latitude, end_lng AS longitude
  FROM trips
  WHERE end_station_id IS NOT NULL )
SELECT
  id,
  FIRST(name, true) AS name, AVG(latitude) AS latitude, AVG(longitude) AS longitude,
  COUNT(*) AS no_trips
FROM trip_starts
GROUP BY id;

-- Identifiers of the same station: same name, less than 1 m apart
DROP TABLE IF EXISTS station_duplicates;
CREATE TABLE station_duplicates
USING DELTA
AS SELECT d.id AS dup_id, k.id AS keep_id
FROM stations_clean d JOIN stations_clean k
  ON d.name = k.name AND d.id <> k.id AND k.no_trips > d.no_trips AND
  ST_DistanceSphere(ST_Point(d.longitude, d.latitude),
    ST_Point(k.longitude, k.latitude)) < 1;

MERGE INTO trips t USING station_duplicates d ON t.start_station_id = d.dup_id
WHEN MATCHED THEN UPDATE SET t.start_station_id = d.keep_id;

MERGE INTO trips t USING station_duplicates d ON t.end_station_id = d.dup_id
WHEN MATCHED THEN UPDATE SET t.end_station_id = d.keep_id;

-- MERGE against the view, which reads the trips with the kept identifiers
MERGE INTO stations s USING stations_clean n ON s.id = n.id
WHEN MATCHED THEN UPDATE SET
  s.name = n.name, s.latitude = n.latitude, s.longitude = n.longitude,
  s.geometry = ST_Point(n.longitude, n.latitude)
WHEN NOT MATCHED THEN INSERT (
  id, name, latitude, longitude, geometry, boroname, ntacode, ntaname)
VALUES (
  n.id, n.name, n.latitude, n.longitude,
  ST_Point(n.longitude, n.latitude),
  NULL, NULL, NULL);

MERGE INTO stations s
USING nta n
ON ST_Within(s.geometry, n.geometry)
WHEN MATCHED THEN
  UPDATE SET s.boroname = n.boroname, s.ntacode = n.nta2020,
    s.ntaname = n.ntaname;

DROP TABLE IF EXISTS boroughs;
CREATE TABLE boroughs
USING DELTA
AS SELECT boroname, ST_Union_Aggr(geometry) AS geometry
FROM nta
GROUP BY boroname;

-- The numbers that the chapter and the appendix give
SELECT 'trips' AS table_name, COUNT(*) AS n FROM trips
UNION ALL SELECT 'stations', COUNT(*) FROM stations
UNION ALL SELECT 'stations in an NTA', COUNT(*) FROM stations WHERE boroname IS NOT NULL
UNION ALL SELECT 'station_duplicates', COUNT(*) FROM station_duplicates
UNION ALL SELECT 'nta', COUNT(*) FROM nta
UNION ALL SELECT 'boroughs', COUNT(*) FROM boroughs;
