-- Load the BerlinMOD-Hanoi tables of a PostgreSQL database with MobilityDB into DuckDB, with the
-- tables and columns of the companion notebook chapter7/hanoi-book.ipynb, and create the table
-- Bins and the view Trips200 of the chapter. The geometries come over as WKT, since the postgres
-- scanner reads a PostGIS geometry as text; the trajectory is computed in DuckDB, as the AIS
-- section does for the table Ships. The PostgreSQL server and database are those of the libpq
-- variables PGHOST, PGPORT, PGUSER and PGDATABASE; the timestamps of the data set are in UTC.
SET TimeZone = 'UTC';
INSTALL postgres;
LOAD postgres;
ATTACH 'options=-ctimezone=UTC' AS pg (TYPE postgres, READ_ONLY);

CREATE OR REPLACE TABLE trips (
    tripid integer PRIMARY KEY,
    vehicleid integer NOT NULL,
    seqNo integer NOT NULL,
    trip tgeompoint,
    trajectory geometry);
INSERT INTO trips
SELECT tripid, vehicleid, seqNo, trip, NULL
FROM postgres_query('pg', 'SELECT tripid, vehicleid, seqno, trip FROM trips ORDER BY tripid');
UPDATE trips SET trajectory = trajectory(trip)::geometry;

CREATE OR REPLACE TABLE municipalities(
    municipalityid BIGINT PRIMARY KEY,
    municipalityname VARCHAR,
    population BIGINT,
    percpop DOUBLE,
    popdensitykm2 BIGINT,
    noenterp BIGINT,
    percenterp DOUBLE,
    municipalitygeo GEOMETRY);
INSERT INTO municipalities
SELECT municipalityid, municipalityname, population, percpop, popdensitykm2, noenterp,
  percenterp, ST_GeomFromText(geo)
FROM postgres_query('pg', 'SELECT municipalityid, municipalityname, population, percpop,
  popdensitykm2, noenterp, percenterp, ST_AsText(municipalitygeo) AS geo
  FROM municipalities ORDER BY municipalityid');

CREATE OR REPLACE TABLE Instants(instantId integer, instant TIMESTAMPTZ);
INSERT INTO Instants
SELECT * FROM postgres_query('pg', 'SELECT instantid, instant FROM instants ORDER BY instantid');

CREATE OR REPLACE TABLE Licences(LicenceId integer, licence text, VehicleId integer);
INSERT INTO Licences
SELECT * FROM postgres_query('pg', 'SELECT licenceid, licence, vehicleid FROM licences');
CREATE OR REPLACE TABLE Licences1 (LicenceId integer, licence text, VehicleId integer);
INSERT INTO Licences1
SELECT * FROM postgres_query('pg', 'SELECT licenceid, licence, vehicleid FROM licences1');

CREATE OR REPLACE TABLE Vehicles(vehicleid integer, licence text, VehicleType text, model text);
INSERT INTO Vehicles
SELECT * FROM postgres_query('pg', 'SELECT vehicleid, licence, vehicletype, model FROM vehicles
  ORDER BY vehicleid');

CREATE OR REPLACE TABLE Points(PointId integer, Geom geometry);
INSERT INTO Points
SELECT pointid, ST_GeomFromText(geo)
FROM postgres_query('pg', 'SELECT pointid, ST_AsText(geom) AS geo FROM points ORDER BY pointid');

DROP TABLE IF EXISTS Bins;
CREATE OR REPLACE TABLE Bins(PId,SpanP) AS
WITH Temp AS (
  SELECT ROW_NUMBER() OVER() AS pid, h AS startt,
    h + INTERVAL '30 minutes' AS endt
  FROM (
    SELECT generate_series AS h
    FROM generate_series(TIMESTAMPTZ '2020-06-01 00:00:00',
      TIMESTAMPTZ '2020-06-02 23:30:00', INTERVAL '30 minutes') ) AS t )
SELECT Pid, span(startt::timestamptz,endt::timestamptz) as SpanP
FROM Temp;

CREATE OR REPLACE VIEW Trips200 AS SELECT * FROM Trips ORDER BY TripId LIMIT 200;

SELECT 'trips' AS t, COUNT(*) FROM trips UNION ALL
SELECT 'municipalities', COUNT(*) FROM municipalities UNION ALL
SELECT 'vehicles', COUNT(*) FROM vehicles UNION ALL
SELECT 'licences', COUNT(*) FROM licences UNION ALL
SELECT 'licences1', COUNT(*) FROM licences1 UNION ALL
SELECT 'points', COUNT(*) FROM points UNION ALL
SELECT 'instants', COUNT(*) FROM instants UNION ALL
SELECT 'bins', COUNT(*) FROM bins;
