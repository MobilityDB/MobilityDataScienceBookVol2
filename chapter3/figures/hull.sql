-- Fig. ais_hull_turn: the hull of the ro-ro vessel FICARIA SEAWAYS (MMSI 220464000) turning in the
-- harbour of Goeteborg on January 20, 2026, between 18:39 and 18:45, six placements 72 s apart,
-- and the trajectory of its GPS antenna. Reads the table ShipsRigid of chapter 4 in the AIS
-- database of the book.
-- psql -d ais -v out=<dir> -f hull.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
\o :out/hull.geojson
WITH Turn(Trip) AS (
  SELECT atTime(Trip, tstzspan '[2026-01-20 18:39:00+00, 2026-01-20 18:45:00+00]')
  FROM ShipsRigid WHERE MMSI = 220464000 ),
Layer(Name, G) AS (
  SELECT 'p' || i, valueAtTimestamp(t.Trip, timestamptz '2026-01-20 18:39:00+00' + (i * interval '72 s'))
  FROM Turn t, generate_series(0, 5) AS i
  UNION ALL
  SELECT 'antenna', trajectory(tgeompoint(Trip)) FROM Turn )
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name),
  'geometry', ST_AsGeoJSON(ST_Transform(G, 4326), 9)::json))) FROM Layer;
\o
WITH Turn(Trip) AS (
  SELECT atTime(Trip, tstzspan '[2026-01-20 18:39:00+00, 2026-01-20 18:45:00+00]')
  FROM ShipsRigid WHERE MMSI = 220464000 ),
G(G) AS (SELECT traversedArea(Trip) FROM Turn)
SELECT ST_AsText(ST_Transform(ST_Centroid(ST_Envelope(G)), 4326)),
  round(ST_XMax(G) - ST_XMin(G)), round(ST_YMax(G) - ST_YMin(G)), ST_SRID(G) FROM G;
