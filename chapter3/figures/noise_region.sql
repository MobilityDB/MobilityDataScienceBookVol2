-- Fig. ais_noise_region: the noise region of the fishing vessel SLESVIG (220323000, trip 1) leaving
-- the harbour of Oesterby at 4:15, 4:30, 4:45, 5:00 and 5:15, and its trajectory from 4:00 to 5:15.
-- psql -d noise -v out=<dir> -f noise_region.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
\o :out/noise_region.geojson
WITH Layer(Name, G) AS (
  SELECT 'c' || i, geometry(valueAtTimestamp(Noise, timestamptz '2026-01-20 04:15:00+00' + i * interval '15 min'))
  FROM VesselTrip, generate_series(0, 4) AS i
  WHERE MMSI = 220323000 AND TripId = 1
  UNION ALL
  SELECT 'trajectory', trajectory(atTime(Trip, tstzspan '[2026-01-20 04:00:00+00, 2026-01-20 05:15:00+00]'))
  FROM VesselTrip WHERE MMSI = 220323000 AND TripId = 1 )
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
SELECT i, round(radius(valueAtTimestamp(Noise, timestamptz '2026-01-20 04:15:00+00' + i * interval '15 min'))::numeric)
FROM VesselTrip, generate_series(0, 4) AS i WHERE MMSI = 220323000 AND TripId = 1;
WITH G(G) AS (
  SELECT ST_Collect(geometry(valueAtTimestamp(Noise, timestamptz '2026-01-20 04:15:00+00' + i * interval '15 min')))
  FROM VesselTrip, generate_series(0, 4) AS i WHERE MMSI = 220323000 AND TripId = 1 )
SELECT ST_AsText(ST_Transform(ST_Centroid(ST_Envelope(G)), 4326)),
  round(ST_XMax(G) - ST_XMin(G)), round(ST_YMax(G) - ST_YMin(G)) FROM G;
