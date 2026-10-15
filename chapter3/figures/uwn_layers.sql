-- Layers of Figs. traversed_area_uwn and shortest_line_uwn: the trajectories of SLESVIG (220323000,
-- trip 1) and MARGRETE LAESOE (219000407, trip 1), the protected areas within 15 km of the traversed
-- area of SLESVIG, the shortest line between the two noise regions, and the lines between them
-- every two hours.  psql -d noise -v out=<dir> -f uwn_layers.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
CREATE TEMP TABLE Layer(Name text, Id text, G geometry);
INSERT INTO Layer SELECT 'traj', MMSI::text, Trajectory FROM VesselTrip
WHERE (MMSI, TripId) IN ((220323000, 1), (219000407, 1));
INSERT INTO Layer SELECT 'areas', n.Id::text, n.Geom
FROM NaturalAreas n, VesselTrip v
WHERE (v.MMSI, v.TripId) = (220323000, 1) AND ST_DWithin(n.Geom, v.TraversedArea, 15000);
INSERT INTO Layer SELECT 'shortest', NULL, shortestLine(a.Noise, b.Noise)
FROM VesselTrip a, VesselTrip b
WHERE (a.MMSI, a.TripId) = (220323000, 1) AND (b.MMSI, b.TripId) = (219000407, 1);
INSERT INTO Layer SELECT 'samples', to_char(t, 'HH24:MI'),
  shortestLine(atTime(a.Noise, t), atTime(b.Noise, t))
FROM VesselTrip a, VesselTrip b,
  generate_series(timestamptz '2026-01-20 02:00+00', '2026-01-20 22:00+00', interval '2 hours') t
WHERE (a.MMSI, a.TripId) = (220323000, 1) AND (b.MMSI, b.TripId) = (219000407, 1)
  AND atTime(a.Noise, t) IS NOT NULL AND atTime(b.Noise, t) IS NOT NULL;
SELECT Name, count(*), string_agg(Id, ',' ORDER BY Id) FROM Layer GROUP BY Name ORDER BY Name;
\o :out/uwn_layers.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name, 'id', Id),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
