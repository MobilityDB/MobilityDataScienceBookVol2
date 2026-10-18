-- The fingerprints of the Hanoi tables of chapter 7 loaded by hanoi_pg.sql: the number of rows
-- and the MD5 of their keys, one line per row in a total order. A trip is keyed by its
-- identifier, its vehicle, its first and last instants in microseconds since 1970 and its number
-- of instants; a municipality by its identifier and the text of its geometry. The last line is
-- the length of the trips within the municipality of Soc Son, clipped by PostGIS.
--
--   psql -d hanoi -At -f load/hanoi_fingerprint.sql

SELECT 'trips', count(*), sum(numInstants(Trip)), md5(string_agg(
  TripId || ',' || VehicleId || ',' ||
  (EXTRACT(EPOCH FROM startTimestamp(Trip)) * 1000000)::bigint || ',' ||
  (EXTRACT(EPOCH FROM endTimestamp(Trip)) * 1000000)::bigint || ',' || numInstants(Trip), ';'
  ORDER BY TripId))
FROM Trips;

SELECT 'municipalities', count(*), md5(string_agg(
  MunicipalityId || ',' || ST_AsText(MunicipalityGeo), ';' ORDER BY MunicipalityId))
FROM Municipalities;

SELECT 'socson', count(*), round((sum(ST_Length(ST_Intersection(t.Trajectory,
  m.MunicipalityGeo))) / 1000)::numeric, 3)
FROM Trips t, Municipalities m
WHERE m.MunicipalityName = 'Huyện Sóc Sơn' AND ST_Intersects(t.Trajectory, m.MunicipalityGeo);
