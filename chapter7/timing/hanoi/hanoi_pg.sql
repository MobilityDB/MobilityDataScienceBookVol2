-- Create in the PostgreSQL database of the BerlinMOD-Hanoi data set the table Bins and the view
-- Trips200 of the chapter, which the MobilityDB twins pg_h6.sql and pg_h8.sql read, as
-- hanoi_duckdb.sql creates them in DuckDB. The timestamps of the data set are in UTC.
\set ON_ERROR_STOP on
SET TimeZone = 'UTC';
DROP TABLE IF EXISTS Bins;
CREATE TABLE Bins(PId,SpanP) AS
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
SELECT COUNT(*) AS bins FROM Bins;
