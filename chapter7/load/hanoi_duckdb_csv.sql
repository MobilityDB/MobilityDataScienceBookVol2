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

-- The Hanoi tables of chapter 7 in DuckDB with MobilityDuck, read from the CSV files of
-- hanoi_sf0.01.zip in ${HANOI_DIR}, with no PostgreSQL: the tables and columns that
-- load/hanoi_duckdb.sql copies from the database that load/hanoi_pg.sql loads, built as
-- load/hanoi_pg.sql builds them. The trips are assembled from their instants in longitude and
-- latitude transformed to EPSG:3857, each instant before the sequence is assembled, since the
-- sequence drops the instants that are collinear in EPSG:3857; the municipalities are in
-- EPSG:3857.
INSTALL spatial;
LOAD spatial;
LOAD '${MOBILITYDUCK_EXTENSION}';
SET TimeZone = 'UTC';
CREATE OR REPLACE TABLE Trips AS
SELECT TripId, VehicleId,
  tgeompointSeq(array_agg(transform(tgeompoint(ST_Point(PosX, PosY), t, 4326), 3857)
    ORDER BY t)) AS Trip
FROM read_csv('${HANOI_DIR}/tripsinput.csv', header = true, columns = {'TripId': 'INTEGER',
  'VehicleId': 'INTEGER', 'PosX': 'DOUBLE', 'PosY': 'DOUBLE', 't': 'TIMESTAMPTZ'})
GROUP BY VehicleId, TripId
ORDER BY TripId;
ALTER TABLE Trips ADD COLUMN Trajectory GEOMETRY;
UPDATE Trips SET Trajectory = trajectory(Trip);
CREATE OR REPLACE TABLE Municipalities AS
SELECT MunicipalityId, MunicipalityName, Population, PercPop, PopDensityKm2, NoEnterp,
  PercEnterp, ST_GeomFromHEXEWKB(MunicipalityGeo) AS MunicipalityGeo
FROM read_csv('${HANOI_DIR}/municipalities.csv', header = true, columns = {
  'MunicipalityId': 'INTEGER', 'MunicipalityName': 'VARCHAR', 'Population': 'INTEGER',
  'PercPop': 'DOUBLE', 'PopDensityKm2': 'INTEGER', 'NoEnterp': 'INTEGER',
  'PercEnterp': 'DOUBLE', 'MunicipalityGeo': 'VARCHAR'});
CREATE OR REPLACE TABLE Points AS
SELECT PointId, PosX, PosY, ST_Point(PosX, PosY) AS Geom
FROM read_csv('${HANOI_DIR}/points.csv', header = true, columns = {'PointId': 'INTEGER',
  'PosX': 'DOUBLE', 'PosY': 'DOUBLE'});
CREATE OR REPLACE TABLE Vehicles AS
SELECT * FROM read_csv('${HANOI_DIR}/vehicles.csv', header = true, columns = {
  'VehicleId': 'INTEGER', 'Licence': 'VARCHAR', 'VehicleType': 'VARCHAR', 'Model': 'VARCHAR'});
-- licences.csv opens with an empty line before its header
CREATE OR REPLACE TABLE Licences AS
SELECT * FROM read_csv('${HANOI_DIR}/licences.csv', skip = 1, header = true, columns = {
  'LicenceId': 'INTEGER', 'Licence': 'VARCHAR', 'VehicleId': 'INTEGER'});
CREATE OR REPLACE VIEW Licences1 AS SELECT * FROM Licences ORDER BY LicenceId LIMIT 10;
SELECT (SELECT COUNT(*) FROM Trips) AS trips, (SELECT COUNT(*) FROM Municipalities) AS munis,
  (SELECT COUNT(*) FROM Points) AS points, (SELECT COUNT(*) FROM Vehicles) AS vehicles,
  (SELECT SUM(numInstants(Trip)) FROM Trips) AS instants,
  (SELECT round(SUM(ST_Area(MunicipalityGeo))) FROM Municipalities) AS area;
