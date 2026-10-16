-- The BerlinMOD-Hanoi data of scale factor 0.01 (hanoi_sf0.01.zip of
-- github.com/MobilityDB/MobilityDB-BerlinMOD-Hanoi) in PostgreSQL with MobilityDB, in the
-- tables of chapter 7. The CSV files are those MobilityDuck's benchmark/BerlinMOD/sql/load
-- reads: the trips in longitude and latitude, transformed to EPSG:3857 as that loader does,
-- the points and the municipalities in EPSG:3857.
--
--   psql -d hanoi -v dir=<directory of the CSV files> -f load_hanoi.sql

\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

DROP TABLE IF EXISTS Instants, Periods, Points, Municipalities, Vehicles, Licences,
  TripsInput, Trips CASCADE;

CREATE TABLE Instants(InstantId integer PRIMARY KEY, Instant timestamptz);
\set f :dir '/instants.csv'
COPY Instants FROM :'f' CSV HEADER;

CREATE TABLE Periods(PeriodId integer PRIMARY KEY, BeginP timestamptz, EndP timestamptz,
  Period tstzspan);
\set f :dir '/periods.csv'
COPY Periods(PeriodId, BeginP, EndP) FROM :'f' CSV HEADER;
UPDATE Periods SET Period = span(BeginP, EndP);

CREATE TABLE Points(PointId integer PRIMARY KEY, PosX float, PosY float,
  Geom geometry(Point, 3857));
\set f :dir '/points.csv'
COPY Points(PointId, PosX, PosY) FROM :'f' CSV HEADER;
UPDATE Points SET Geom = ST_SetSRID(ST_Point(PosX, PosY), 3857);

CREATE TABLE Municipalities(MunicipalityId integer PRIMARY KEY, MunicipalityName text,
  Population integer, PercPop float, PopDensityKm2 integer, NoEnterp integer,
  PercEnterp float, MunicipalityGeo geometry);
\set f :dir '/municipalities.csv'
COPY Municipalities FROM :'f' CSV HEADER;
CREATE INDEX ON Municipalities USING gist(MunicipalityGeo);

CREATE TABLE Vehicles(VehicleId integer PRIMARY KEY, Licence text, VehicleType text,
  Model text);
\set f :dir '/vehicles.csv'
COPY Vehicles FROM :'f' CSV HEADER;

CREATE TABLE Licences(LicenceId integer PRIMARY KEY, Licence text, VehicleId integer
  REFERENCES Vehicles(VehicleId));
-- licences.csv opens with an empty line before its header
\set f 'sed 1d ' :dir '/licences.csv'
COPY Licences FROM PROGRAM :'f' CSV HEADER;
CREATE VIEW Licences1 AS SELECT * FROM Licences ORDER BY LicenceId LIMIT 10;

CREATE TABLE TripsInput(TripId integer, VehicleId integer, PosX float, PosY float,
  t timestamptz, PRIMARY KEY (TripId, t));
\set f :dir '/tripsinput.csv'
COPY TripsInput FROM :'f' CSV HEADER;

CREATE TABLE Trips(TripId integer, VehicleId integer REFERENCES Vehicles(VehicleId),
  Trip tgeompoint NOT NULL, Trajectory geometry, PRIMARY KEY (VehicleId, TripId));
INSERT INTO Trips(TripId, VehicleId, Trip)
SELECT TripId, VehicleId, tgeompointSeq(array_agg(tgeompoint(
  ST_Transform(ST_SetSRID(ST_Point(PosX, PosY), 4326), 3857), t) ORDER BY t))
FROM TripsInput
GROUP BY VehicleId, TripId;
UPDATE Trips SET Trajectory = trajectory(Trip);
CREATE INDEX ON Trips USING gist(Trip);
CREATE INDEX ON Trips USING gist(Trajectory);
ANALYZE;
SELECT (SELECT count(*) FROM Trips) AS trips, (SELECT count(*) FROM Vehicles) AS vehicles,
  (SELECT count(*) FROM Municipalities) AS municipalities, (SELECT count(*) FROM Points) AS points,
  (SELECT min(startTimestamp(Trip)) FROM Trips) AS first, (SELECT max(endTimestamp(Trip)) FROM Trips) AS last;
