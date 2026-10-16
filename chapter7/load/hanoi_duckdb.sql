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
SELECT (SELECT count(*) FROM Trips) AS trips, (SELECT count(*) FROM Municipalities) AS munis,
  (SELECT count(*) FROM Points) AS points, (SELECT count(*) FROM Vehicles) AS vehicles,
  (SELECT sum(numInstants(Trip)) FROM Trips) AS instants,
  (SELECT round(sum(ST_Area(MunicipalityGeo))) FROM Municipalities) AS area;
