-- The fingerprints of AISClean and Segments that check_duckdb.sh compares with those of the
-- MobilityLakehouse pipeline: the number of rows and the MD5 of their keys, one line per row in
-- a total order. A report is keyed by its vessel, its instant in microseconds since 1970 and its
-- piece; a segment by its vessel, piece, type, first and last instants and number of reports.
--
--   psql -d ais -At -f fingerprint.sql

SELECT 'clean', count(*), md5(string_agg(
  MMSI || ',' || (EXTRACT(EPOCH FROM T) * 1000000)::bigint || ',' || Piece, ';'
  ORDER BY MMSI, T))
FROM AISClean;

SELECT 'segments', count(*), md5(string_agg(
  MMSI || ',' || Piece || ',' || SegmentType || ',' ||
  (EXTRACT(EPOCH FROM TStart) * 1000000)::bigint || ',' ||
  (EXTRACT(EPOCH FROM TEnd) * 1000000)::bigint || ',' || NoPoints, ';'
  ORDER BY MMSI, TStart, TEnd, SegmentType))
FROM Segments;
