-- The fingerprints of fingerprint.sql, computed by DuckDB over the clean reports and the segments
-- that the MobilityLakehouse pipeline writes for a period, in the directory named by the
-- variable out. The piece number and the number of reports are written as integers, as
-- PostgreSQL writes them.
--
--   duckdb -noheader -list -cmd "SET VARIABLE out = '<dir>'" -f fingerprint_duckdb.sql

SELECT 'clean', count(*), md5(string_agg(
  mmsi || ',' || epoch_us(t) || ',' || seq::BIGINT, ';' ORDER BY mmsi, t))
FROM read_parquet(getvariable('out') || '/clean/*.parquet');

SELECT 'segments', count(*), md5(string_agg(
  mmsi || ',' || seq::BIGINT || ',' || segment_type || ',' || epoch_us(t0) || ','
  || epoch_us(t1) || ',' || npoints::BIGINT, ';' ORDER BY mmsi, t0, t1, segment_type))
FROM read_parquet(getvariable('out') || '/segments/*.parquet');
