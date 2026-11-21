-- Export the layers of the figure of the three cell grids (fig:tess_cellgrids): the track of the
-- pilot boat VENUS (MMSI 219002732) leaving Frederikshavn on January 25, 2026, from 07:39:04 to
-- 09:02:03 UTC, from the column TripLonLat of Ships, on the H3, QUADBIN, and S2 grids, with the
-- cells it crosses (th3index, tquadbin, ts2cell) and the protected areas 3 (Waters around
-- Hirsholmene) and 163 (Frederikshavn Kommune public) of NaturalAreas. One column per grid: the
-- upper row draws H3 8, QUADBIN 15, and S2 14 over the whole track, the lower row one resolution
-- finer over the excerpt outlined in black above, the exit of the harbour. Writes cellgrids.geojson
-- and cellgrids_frames.txt, which cellgrids_panels.py draws, to the directory :out.
--
-- The database is the AIS database of that day, built by ais/build.sh 2026-01-25, with the
-- ports and protected areas of load_aux_tables.sql:
--   psql -v out=<dir> -f export_cellgrids.sql
--
-- The layout and the colours are those of the figure tcell_grids of the MobilityDB manual
-- (doc/images/cellindex.png), whose lower frame the lower row keeps: the panels are 700 x 380
-- pixels in EPSG:3857, the upper frame is the box of the track and of the excerpt widened by a
-- fifth in that aspect, and the lower frame is the excerpt of the manual.
\set ON_ERROR_STOP on
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';

CREATE TEMP TABLE Track AS
SELECT MMSI, atTime(TripLonLat, tstzspan '[2026-01-25 07:39:04+00, 2026-01-25 09:02:03+00]') AS Trip
FROM Ships WHERE MMSI = 219002732;
CREATE TEMP TABLE Mpa AS
SELECT Id, ST_Transform(Geom, 4326) AS Geom FROM NaturalAreas WHERE Id IN (3, 163);

CREATE TEMP TABLE Frame(Panel text PRIMARY KEY, Grid text, Res int, Geom geometry(Polygon, 3857));
-- The excerpt: the exit of the harbour
INSERT INTO Frame
SELECT g || '_' || r, g, r, ST_MakeEnvelope(1172401.8, 7846811.4, 1178676.0, 7850217.4, 3857)
FROM (VALUES ('h3', 9), ('quadbin', 16), ('s2', 15)) AS v(g, r);
-- The whole track: the box of the track and of the excerpt, widened by a fifth in the aspect of
-- a panel
INSERT INTO Frame
SELECT g || '_' || r, g, r, ST_MakeEnvelope(cx - w / 2, cy - w * 380 / 700 / 2, cx + w / 2,
  cy + w * 380 / 700 / 2, 3857)
FROM (SELECT (ST_XMin(b) + ST_XMax(b)) / 2 AS cx, (ST_YMin(b) + ST_YMax(b)) / 2 AS cy,
        greatest(ST_XMax(b) - ST_XMin(b), (ST_YMax(b) - ST_YMin(b)) * 700 / 380.0) * 1.2 AS w
      FROM (SELECT ST_Extent(g) AS b FROM (
              SELECT ST_Transform(trajectory(Trip), 3857) AS g FROM Track
              UNION ALL SELECT Geom FROM Frame WHERE Panel = 'h3_9') x) e) c,
  (VALUES ('h3', 8), ('quadbin', 15), ('s2', 14)) AS v(g, r);

-- Every cell meeting each frame, and the cells the track crosses
CREATE TEMP TABLE Grid AS
WITH F AS (SELECT Panel, Grid, Res, ST_Transform(ST_Segmentize(Geom, 50), 4326) AS G FROM Frame)
SELECT F.Panel, cellToBoundary(c) AS Geom FROM F, unnest(gridDisk(geoToH3IndexSet(F.G, F.Res), 1)) c
WHERE F.Grid = 'h3' AND ST_Intersects(cellToBoundary(c), F.G)
UNION ALL
SELECT F.Panel, cellToBoundary(c) FROM F, unnest(gridDisk(geoToQuadbinSet(F.G, F.Res), 1)) c
WHERE F.Grid = 'quadbin' AND ST_Intersects(cellToBoundary(c), F.G)
UNION ALL
SELECT F.Panel, cellToBoundary(c) FROM F, unnest(geoToS2CellSet(F.G::geography, F.Res)) c
WHERE F.Grid = 's2' AND ST_Intersects(cellToBoundary(c)::geometry, F.G);
CREATE TEMP TABLE Crossed AS
SELECT f.Panel, c::text AS Cell, cellToBoundary(c) AS Geom, cellArea(c) AS Area
FROM Frame f, Track t, unnest(getValues(th3index(t.Trip, f.Res))) c WHERE f.Grid = 'h3'
UNION ALL
SELECT f.Panel, c::text, cellToBoundary(c), cellArea(c)
FROM Frame f, Track t, unnest(getValues(tquadbin(t.Trip, f.Res))) c WHERE f.Grid = 'quadbin'
UNION ALL
SELECT f.Panel, c::text, cellToBoundary(c), cellArea(c)
FROM Frame f, Track t, unnest(getValues(ts2cell(t.Trip, f.Res))) c WHERE f.Grid = 's2';

-- Panel | cells of the grid drawn | cells crossed | mean area of a crossed cell (km2), the areas
-- the panel titles of cellgrids_compose.tex state
SELECT f.Panel, (SELECT count(*) FROM Grid g WHERE g.Panel = f.Panel) AS GridCells,
  count(c.*) AS Crossed, round((avg(c.Area) / 1e6)::numeric, 3) AS MeanAreaKm2
FROM Frame f LEFT JOIN Crossed c USING (Panel) GROUP BY f.Panel ORDER BY f.Panel;

\o :out/cellgrids.geojson
SELECT json_build_object('type', 'FeatureCollection', 'features', json_agg(json_build_object(
  'type', 'Feature', 'properties', json_build_object('layer', L, 'panel', P),
  'geometry', ST_AsGeoJSON(G, 9)::json)))
FROM (
  SELECT 'grid' AS L, Panel AS P, ST_SetSRID(Geom::geometry, 4326) AS G FROM Grid
  UNION ALL SELECT 'crossed', Panel, ST_SetSRID(Geom::geometry, 4326) FROM Crossed
  UNION ALL SELECT 'track', 'all', trajectory(Trip) FROM Track
  UNION ALL SELECT 'mpa', 'all', Geom FROM Mpa
  UNION ALL SELECT 'excerpt', 'all', ST_Transform(Geom, 4326) FROM Frame WHERE Panel = 'h3_9'
) x;
\o
\o :out/cellgrids_frames.txt
SELECT Panel, ST_XMin(Geom), ST_YMin(Geom), ST_XMax(Geom), ST_YMax(Geom) FROM Frame ORDER BY Panel;
\o
