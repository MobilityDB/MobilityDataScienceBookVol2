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

-- The Hanoi tables of chapter 7 in DuckDB with MobilityDuck, read from the PostgreSQL database
-- hanoi, ${PG_HANOI} (loaded by load/hanoi_pg.sql) with postgres_scan, as the chapter's
-- listing of the table Ships reads its rows.
INSTALL spatial FROM core_nightly;
INSTALL postgres;
LOAD spatial;
LOAD '${MOBILITYDUCK_EXTENSION}';
LOAD postgres;
CREATE OR REPLACE TABLE Trips AS
SELECT TripId, VehicleId, Trip::tgeompoint AS Trip
FROM postgres_scan('${PG_HANOI}', 'public', 'trips');
ALTER TABLE Trips ADD COLUMN Trajectory GEOMETRY;
UPDATE Trips SET Trajectory = trajectory(Trip);
CREATE OR REPLACE TABLE Municipalities AS
SELECT MunicipalityId, MunicipalityName, Population, PercPop, PopDensityKm2, NoEnterp,
  PercEnterp, MunicipalityGeo
FROM postgres_scan('${PG_HANOI}', 'public', 'municipalities');
CREATE OR REPLACE TABLE Points AS
SELECT PointId, PosX, PosY, ST_Point(PosX, PosY) AS Geom
FROM postgres_scan('${PG_HANOI}', 'public', 'points');
CREATE OR REPLACE TABLE Vehicles AS
SELECT * FROM postgres_scan('${PG_HANOI}', 'public', 'vehicles');
CREATE OR REPLACE TABLE Licences AS
SELECT * FROM postgres_scan('${PG_HANOI}', 'public', 'licences');
CREATE OR REPLACE VIEW Licences1 AS SELECT * FROM Licences ORDER BY LicenceId LIMIT 10;
SELECT (SELECT COUNT(*) FROM Trips) AS trips, (SELECT COUNT(*) FROM Municipalities) AS munis,
  (SELECT COUNT(*) FROM Points) AS points, (SELECT COUNT(*) FROM Vehicles) AS vehicles,
  (SELECT SUM(numInstants(Trip)) FROM Trips) AS instants,
  (SELECT round(SUM(ST_Area(MunicipalityGeo))) FROM Municipalities) AS area;
