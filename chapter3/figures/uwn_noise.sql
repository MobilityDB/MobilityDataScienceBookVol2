-- Noise layer of Figs. traversed_area_uwn and shortest_line_uwn: the traversed areas, as single
-- geometries, of the noise of SLESVIG (220323000, trip 1) and MARGRETE LAESOE (219000407, trip 1).
-- psql -d noise -v out=<dir> -f uwn_noise.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
\timing on
SET TimeZone = 'UTC';
CREATE TEMP TABLE Layer AS
SELECT MMSI::text AS mmsi, traversedArea(Noise, true) AS G
FROM VesselTrip WHERE (MMSI, TripId) IN ((220323000, 1), (219000407, 1));
SELECT mmsi, GeometryType(G), round((ST_Area(G) / 1e6)::numeric, 2) FROM Layer;
\o :out/uwn_noise.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', 'noise', 'mmsi', mmsi),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
SELECT mmsi, ST_XMin(G), ST_YMin(G), ST_XMax(G), ST_YMax(G) FROM Layer;
