-- The table FlightsInputRaw: the state vectors of the OpenSky Network with the 16 columns of the
-- table state_vectors of its historical database, unchanged, under the names of chapter 5 of
-- the first volume. The column time of the files is Et. The types are those of the notebook
-- chapter8/8.3 Create tables from scratch-flights-MobilitySpark.ipynb. build.sh appends one
-- Parquet file per hour, which DuckDB reads and hands over as CSV, with
--
--   duckdb -c "COPY (SELECT time, icao24, ..., lastContact FROM '<file>.parquet') TO STDOUT
--     (FORMAT csv, HEADER)" | psql -d flights -c "\copy FlightsInputRaw FROM STDIN CSV HEADER"
--
--   psql -d flights -f flights_load.sql

\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

DROP TABLE IF EXISTS FlightsInputRaw;
CREATE TABLE FlightsInputRaw(
  Et bigint,
  ICAO24 text,
  Lat float,
  Lon float,
  Velocity float,
  Heading float,
  VertRate float,
  CallSign text,
  OnGround boolean,
  Alert boolean,
  SPI boolean,
  Squawk integer,
  BaroAltitude float,
  GeoAltitude float,
  LastPosUpdate float,
  LastContact float
);
