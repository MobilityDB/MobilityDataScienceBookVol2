-- Copy the table Ships of the AIS database of the book (PostgreSQL with MobilityDB) into a
-- DuckDB database with MobilityDuck, with the columns of the companion notebook
-- mobilityDuckAIS.ipynb, and add the trajectory of each ship as a geometry. The PostgreSQL
-- server and database are those of the libpq variables PGHOST, PGPORT, PGUSER and PGDATABASE.
SET TimeZone = 'UTC';
INSTALL postgres;
LOAD postgres;
CREATE OR REPLACE TABLE ships (MMSI integer, Trip tgeompoint, SOG tfloat,
 COG tfloat);
INSERT INTO ships
SELECT MMSI, Trip, SOG, COG
FROM postgres_scan('options=-ctimezone=UTC', 'public', 'ships');
SET threads=1;
SET memory_limit='7000MB';
SELECT COUNT(*) FROM ships;
ALTER TABLE ships ADD column trajectory geometry;
UPDATE ships set trajectory = trajectory(trip)::geometry;
