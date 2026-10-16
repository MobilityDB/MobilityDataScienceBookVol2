-- Layers of Figs. traversed_area_uwn and shortest_line_uwn: the trajectories of SLESVIG (220323000,
-- trip 1) and MARGRETE LAESOE (219000407, trip 1), the protected areas within 15 km of the traversed
-- area of SLESVIG, the shortest line between the two noise regions, and the lines between them
-- every two hours.  psql -d noise -v out=<dir> -f uwn_layers.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
CREATE TEMP TABLE Layer(Name text, Id text, G geometry);
INSERT INTO Layer SELECT 'traj', MMSI::text, trajectory(Trip) FROM Ships
WHERE MMSI IN (220323000, 219000407);
INSERT INTO Layer
WITH v AS MATERIALIZED (
  SELECT ST_UnaryUnion(ST_CurveToLine(traversedArea(Noise), 64)) AS G
  FROM Ships WHERE MMSI = 220323000 )
SELECT 'areas', n.Id::text, n.Geom
FROM NaturalAreas n, v
WHERE ST_DWithin(n.Geom, v.G, 15000);
INSERT INTO Layer SELECT 'shortest', NULL, shortestLine(a.Noise, b.Noise)
FROM Ships a, Ships b
WHERE a.MMSI = 220323000 AND b.MMSI = 219000407;
INSERT INTO Layer SELECT 'samples', to_char(t, 'HH24:MI'),
  shortestLine(atTime(a.Noise, t), atTime(b.Noise, t))
FROM Ships a, Ships b,
  generate_series(timestamptz '2026-01-20 05:00+00', '2026-01-20 17:00+00', interval '30 minutes') t
WHERE a.MMSI = 220323000 AND b.MMSI = 219000407
  AND atTime(a.Noise, t) IS NOT NULL AND atTime(b.Noise, t) IS NOT NULL;
SELECT Name, count(*), string_agg(Id, ',' ORDER BY Id) FROM Layer GROUP BY Name ORDER BY Name;
\o :out/uwn_layers.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name, 'id', Id),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
