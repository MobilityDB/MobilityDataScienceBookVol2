-- Fig. ais_encounter_sea: the trajectories of the two vessels of the longest encounter at sea, TRIUMF
-- (273277840) and PUMA (319114200), and their noise regions at 4:00, 12:00 and 20:00.
-- psql -d noise -v out=<dir> -f encounter_sea.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
CREATE TEMP TABLE Layer(Name text, G geometry);
INSERT INTO Layer SELECT 'traj' || MMSI, Trajectory FROM VesselTrip
WHERE (MMSI, TripId) IN ((273277840, 1), (319114200, 1));
INSERT INTO Layer SELECT 'n' || MMSI || '_' || to_char(t, 'HH24'), geometry(valueAtTimestamp(Noise, t))
FROM VesselTrip, unnest(ARRAY[timestamptz '2026-01-20 04:00+00', '2026-01-20 12:00+00',
  '2026-01-20 20:00+00']) AS t
WHERE (MMSI, TripId) IN ((273277840, 1), (319114200, 1));
SELECT Name, round(ST_Area(G)) FROM Layer ORDER BY Name;
\o :out/encounter_sea.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
SELECT ST_AsText(ST_Transform(ST_Envelope(ST_Collect(G)), 4326)) FROM Layer;
