-- The fingerprints of the Hanoi tables of chapter 7, in PostgreSQL (load/hanoi_pg.sql) or in
-- DuckDB (load/hanoi_duckdb.sql, load/hanoi_duckdb_csv.sql): the number of rows and the MD5 of
-- their keys, one line per row in a total order. A trip is keyed by its identifier, its vehicle,
-- its first and last instants in microseconds since 1970 and its number of instants; a
-- municipality by its identifier and its area in square meters rounded to the millimeter. The
-- last line is the length of the trips within the municipality of Soc Son.
--
--   psql -d hanoi -At -f load/hanoi_fingerprint.sql
--   duckdb -unsigned hanoi.duckdb -c "LOAD spatial" -c "LOAD '<mobilityduck extension>'" \
--     -c ".read load/hanoi_fingerprint.sql"

SELECT 'trips', count(*), sum(numInstants(Trip)), md5(string_agg(
  CAST(TripId AS text) || ',' || CAST(VehicleId AS text) || ',' ||
  CAST(CAST(EXTRACT(EPOCH FROM startTimestamp(Trip)) * 1000000 AS bigint) AS text) || ',' ||
  CAST(CAST(EXTRACT(EPOCH FROM endTimestamp(Trip)) * 1000000 AS bigint) AS text) || ',' ||
  CAST(numInstants(Trip) AS text), ';' ORDER BY TripId))
FROM Trips;

SELECT 'municipalities', count(*), md5(string_agg(
  CAST(MunicipalityId AS text) || ',' ||
  CAST(CAST(round(ST_Area(MunicipalityGeo) * 1000) AS bigint) AS text), ';'
  ORDER BY MunicipalityId))
FROM Municipalities;

SELECT 'socson', count(*), round(CAST(sum(ST_Length(ST_Intersection(t.Trajectory,
  m.MunicipalityGeo))) / 1000 AS numeric), 3)
FROM Trips t, Municipalities m
WHERE m.MunicipalityName = 'Huyện Sóc Sơn' AND ST_Intersects(t.Trajectory, m.MunicipalityGeo);
