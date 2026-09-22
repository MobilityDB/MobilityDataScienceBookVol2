-- Input table for one Danish AIS day: the columns of the Danish Maritime Authority CSV, as in
-- the MobilityDB workshop's AISInput. MMSI is bigint and text columns are unbounded, so a single
-- malformed value cannot abort the load.
--
--   psql -d aisdk -f aisdk_load.sql
--   unzip -p aisdk-2026-01-20.zip | PGOPTIONS='-c datestyle=ISO,DMY' psql -d aisdk -c "\copy AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG, COG, Heading, IMO, CallSign, Name, ShipType, CargoType, Width, Length, TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType, SizeA, SizeB, SizeC, SizeD) FROM STDIN CSV HEADER"

CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

DROP TABLE IF EXISTS AISInput CASCADE;
CREATE TABLE AISInput(
  T timestamp,
  TypeOfMobile text,
  MMSI bigint,
  Latitude float,
  Longitude float,
  NavigationalStatus text,
  ROT float,
  SOG float,
  COG float,
  Heading integer,
  IMO text,
  CallSign text,
  Name text,
  ShipType text,
  CargoType text,
  Width float,
  Length float,
  TypeOfPositionFixingDevice text,
  Draught float,
  Destination text,
  ETA text,
  DataSourceType text,
  SizeA float,
  SizeB float,
  SizeC float,
  SizeD float
);
