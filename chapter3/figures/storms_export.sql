-- The layers of the three maps of Fig. storms, the Atlantic storms of 2024, as one GeoJSON
-- FeatureCollection whose property "layer" names the layer of a feature and "ord" its drawing
-- order within the layer:
--   track   the trajectory of each storm of Storms2024_tpoint, ordered by storm number;
--   inst    the positions of each storm at its observations;
--   radii   the polygons of the wind fields of Storms2024_tgeo, ordered by wind speed and then by
--           time, so that the 50 and 64 knots are drawn over the 34 knots;
--   circle  the circles of the wind fields of 34 knots of Storms2024_tcbuffer, ordered by time.
-- The tables are those storms/storms.sql builds with year=2024.
-- psql -d storms -XAt -f storms_export.sql > storms.geojson
SET TimeZone = 'UTC';
WITH F AS (
  SELECT 1 AS k, substr(StormId, 3, 2)::integer AS ord, 'track' AS layer, Traj AS geom
  FROM Storms2024_tpoint
  UNION ALL
  SELECT 2, substr(StormId, 3, 2)::integer, 'inst', getValue(i)
  FROM Storms2024_tpoint, unnest(instants(Temp)) i
  UNION ALL
  SELECT 3, Radii * 100000 + extract(epoch FROM getTimestamp(i))::bigint / 3600, 'radii', getValue(i)
  FROM Storms2024_tgeo, unnest(instants(Temp)) i
  WHERE ST_Dimension(getValue(i)) = 2
  UNION ALL
  SELECT 4, extract(epoch FROM getTimestamp(i))::bigint / 3600, 'circle',
    ST_CurveToLine(getValue(i)::geometry, 64)
  FROM Storms2024_tcbuffer, unnest(instants(Temp)) i
  WHERE Radii = 34 AND radius(getValue(i)) > 0 )
SELECT json_build_object('type', 'FeatureCollection', 'features', json_agg(
  json_build_object('type', 'Feature', 'properties', json_build_object('layer', layer, 'ord', ord),
    'geometry', ST_AsGeoJSON(geom, 6)::json) ORDER BY k, ord))
FROM F;
