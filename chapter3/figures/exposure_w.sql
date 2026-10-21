-- Fig. ais_exposure_w: the marine strategy area W (122) and the noise regions of the vessels heard in
-- it at the instant of the largest number of them, split by whether they sail faster than 2 knots,
-- into exposure_w.geojson, and the centers of the regions of the vessels sailing at most 2 knots
-- into exposure_w_pts.geojson.
-- psql -d noise -v out=<dir> -f exposure_w.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
CREATE TEMP TABLE Peak AS
SELECT startTimestamp(atMax(tCount(Heard))) AS T FROM Exposure WHERE AreaId = 122;
SELECT T FROM Peak;
CREATE TEMP TABLE Layer(Name text, G geometry);
INSERT INTO Layer SELECT 'area', Geom FROM NaturalAreas WHERE Id = 122;
INSERT INTO Layer
SELECT 'noise',
  geometry(valueAtTimestamp(v.Noise, p.T))
FROM Exposure e JOIN Ships v USING (MMSI), Peak p
WHERE e.AreaId = 122 AND e.Heard @> p.T;
SELECT Name, COUNT(*) FROM Layer GROUP BY Name ORDER BY Name;
\o :out/exposure_w.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
SELECT ST_AsText(ST_Transform(ST_Envelope(G), 4326)) FROM Layer WHERE Name = 'area';
