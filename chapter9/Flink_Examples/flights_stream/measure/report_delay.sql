-- Position reports of the 2026-03-01 day, as the stream sees them: the state vectors at every
-- tenth second that have a squawk and a position, one report per (icao24, lastposupdate), first
-- carried by the state vector of time first_t. The queries count the reports and their
-- aircraft, the delay between the time of a report and the first state vector that carries it,
-- the reports that arrive after a report of the same aircraft with a later time, and the
-- lateness of each report against the largest report time already sent. DuckDB reads the
-- Parquet day that flights/fetch_data.sh downloads into $DATA/flights/parquet:
--
--   DATA=<directory of data> duckdb < report_delay.sql
SET memory_limit='4GB'; SET threads=4; SET temp_directory='duckdb_spill';
CREATE TABLE rep AS
SELECT icao24, lastposupdate AS lpu, MIN(time) AS first_t
FROM read_parquet(getenv('DATA') || '/flights/parquet/*/*.parquet', hive_partitioning=true)
WHERE time % 10 = 0 AND squawk IS NOT NULL AND lat IS NOT NULL AND lon IS NOT NULL
  AND lastposupdate IS NOT NULL
GROUP BY icao24, lastposupdate;
SELECT 'reports' AS k, COUNT(*) AS n, COUNT(DISTINCT icao24) AS aircraft FROM rep;
SELECT 'delay' AS k, quantile_cont(first_t - lpu, [0.5, 0.9, 0.99, 0.999]) AS q, MAX(first_t - lpu) AS mx,
  COUNT(*) FILTER (WHERE first_t - lpu > 10) AS gt10, COUNT(*) FILTER (WHERE first_t - lpu > 20) AS gt20,
  COUNT(*) FILTER (WHERE first_t - lpu > 60) AS gt60, COUNT(*) FILTER (WHERE first_t - lpu < 0) AS neg
FROM rep;
SELECT 'outoforder' AS k, COUNT(*) FILTER (WHERE lpu < prev) AS n FROM (
  SELECT lpu, MAX(lpu) OVER (PARTITION BY icao24 ORDER BY first_t, lpu
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev FROM rep);
SELECT 'lateness' AS k, COUNT(*) FILTER (WHERE late > 10) AS gt10, COUNT(*) FILTER (WHERE late > 30) AS gt30,
  COUNT(*) FILTER (WHERE late > 60) AS gt60, COUNT(*) FILTER (WHERE late > 300) AS gt300, MAX(late) AS mx FROM (
  SELECT MAX(lpu) OVER (ORDER BY first_t RANGE BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) - lpu AS late FROM rep);
