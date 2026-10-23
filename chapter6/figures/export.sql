/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

/* Exports the layers of the map figures of chapter 6 from the database built by build.sh
 * (delhi_load.sql, paris_tours.sql) as GeoJSON in EPSG:4326, each feature carrying the name of its
 * layer in the property "layer", the name that the specs (*.json) of the figures select. The layers
 * are taken from the tables Grid, Trips, TripPoints, TripCells, TripTiles, Districts, and PoI.
 *   psql -At -v dir=<output directory> -f export.sql */

CREATE OR REPLACE FUNCTION pg_temp.feat(layer text, g geometry, props jsonb)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('type', 'Feature',
    'geometry', ST_AsGeoJSON(ST_Transform(g, 4326), 7)::jsonb,
    'properties', props || jsonb_build_object('layer', layer)) $$;

CREATE OR REPLACE FUNCTION pg_temp.fc(feats jsonb[])
RETURNS text LANGUAGE sql AS $$
  SELECT jsonb_build_object('type', 'FeatureCollection',
    'features', to_jsonb(feats))::text $$;

CREATE OR REPLACE FUNCTION pg_temp.grid()
RETURNS SETOF jsonb LANGUAGE sql AS $$
  SELECT pg_temp.feat('grid', Geom, jsonb_build_object('cellid', CellId)) FROM Grid $$;

-- A trip as in the projects "trip 6", "linevspoint" and "query5.14": its trajectory and its points
CREATE OR REPLACE FUNCTION pg_temp.trip(id int, line text, points text)
RETURNS SETOF jsonb LANGUAGE sql AS $$
  SELECT pg_temp.feat(line, Trajectory, jsonb_build_object('tripid', TripId))
  FROM Trips WHERE TripId = id
  UNION ALL
  SELECT pg_temp.feat(points, Geom, jsonb_build_object('tripid', TripId, 't', T, 'pm25', Pm25))
  FROM TripPoints WHERE TripId = id $$;

-- trip6linevspoint: project "trip 6"
\o :dir/trip6.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f UNION ALL SELECT pg_temp.trip(6, 'line 6', 'trip 6')) s;

-- tiledpoint: project "linevspoint", layers "275 line" and "points 275"
\o :dir/trip275.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f UNION ALL SELECT pg_temp.trip(275, '275 line', 'points 275')) s;

-- missingpattern: project "query5.14", layers "2684 line" and "2684 points"
\o :dir/trip2684.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f UNION ALL SELECT pg_temp.trip(2684, '2684 line', '2684 points')) s;

-- grid-allincrease: project "tiledvdpoint", layer "trip 12": the parts of the trip in each cell
-- with the average Pm25 of the cell
\o :dir/trip12.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f
  UNION ALL
  SELECT pg_temp.feat('trip 12', t.Trajectory, jsonb_build_object('tripid', t.TripId,
    'cellid', c.CellId, 'pm25', round(c.Pm25::numeric, 2)))
  FROM TripCells c JOIN TripTiles t ON c.TripId = t.TripId
  WHERE t.TripId = 12 AND c.CellId = t.CellId) s;

-- griddistricts, alternate, development: the districts, the grid, and the trips
\o :dir/districts.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f
  UNION ALL
  SELECT pg_temp.feat('districts', Geom, jsonb_build_object('name', Name)) FROM Districts
  UNION ALL
  SELECT pg_temp.feat('trip ' || TripId, Trajectory, jsonb_build_object('tripid', TripId))
  FROM Trips WHERE TripId IN (3324, 4)
  UNION ALL
  SELECT pg_temp.feat('trips', Trajectory, jsonb_build_object('tripid', TripId))
  FROM Trips WHERE TripId IN (6, 4546, 2232, 71, 21)) s;

-- griddistricts: the grid, the districts, and every trip, each trajectory simplified with a
-- tolerance of 30 m (ST_Simplify), below a pixel of the city-wide map, and written to 6 decimals
\o :dir/griddistricts.geojson
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.grid() AS f
  UNION ALL
  SELECT pg_temp.feat('districts', Geom, jsonb_build_object('name', Name)) FROM Districts
  UNION ALL
  SELECT jsonb_build_object('type', 'Feature',
    'geometry', ST_AsGeoJSON(ST_Transform(ST_Simplify(Trajectory, 30), 4326), 6)::jsonb,
    'properties', jsonb_build_object('tripid', TripId, 'layer', 'alltrips'))
  FROM Trips) s;

-- s-m-Itinerary: the itineraries of John (trip_id 1, in red) and Mary (trip_id 2, in blue) as
-- drawn in the figure, one segment per move between two points of interest of the table PoI, and
-- the points of interest they visit
\o :dir/paris_poi.geojson
WITH Itinerary(TripId, StepNo, Name) AS (
  SELECT 1, s, n FROM unnest(ARRAY['Hilton Paris Opera', 'Musee d''Orsay', 'Le Meurice',
    'Centre Pompidou', 'Hilton Paris Opera']) WITH ORDINALITY AS u(n, s)
  UNION ALL
  SELECT 2, s, n FROM unnest(ARRAY['Holiday Inn Paris Gare de l''Est', 'Musee du Louvre',
    'Le Petit Italien', 'Centre Pompidou', 'Holiday Inn Paris Gare de l''Est'])
    WITH ORDINALITY AS u(n, s) ),
Segments(TripId, Geom) AS (
  SELECT a.TripId, ST_MakeLine(p.Geom, q.Geom)
  FROM Itinerary a, Itinerary b, PoI p, PoI q
  WHERE a.TripId = b.TripId AND b.StepNo = a.StepNo + 1 AND p.Name = a.Name AND q.Name = b.Name )
SELECT pg_temp.fc(array_agg(f)) FROM (
  SELECT pg_temp.feat('pois', Geom, jsonb_build_object('name', Name,
    'category', Description->>'Category')) AS f
  FROM PoI WHERE Name IN (SELECT Name FROM Itinerary)
  UNION ALL
  SELECT pg_temp.feat('trips', Geom, jsonb_build_object('trip_id', TripId)) FROM Segments) s;
\o
