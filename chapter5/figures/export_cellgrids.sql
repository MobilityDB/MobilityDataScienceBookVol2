-- Export the layers of the figure of the three cell grids (fig:tess_cellgrids): the track of the
-- pilot boat DANPILOT VENUS (MMSI 219002732) leaving Frederikshavn between 08:45:29 and 09:52:23
-- UTC, from the column TripLonLat of Ships, on the H3, QUADBIN, and S2 grids, with the cells it
-- crosses (th3index, tquadbin, ts2cell) and the protected area 17 of NaturalAreas. The left
-- column shows H3 8, QUADBIN 15, and S2 14 over the frame of the whole track, the right column one
-- resolution finer over the excerpt outlined in black on the left. Writes cellgrids.geojson and
-- cellgrids_frames.txt, which cellgrids_panels.py draws, to the directory :out.
--
--   psql -v out=<dir> -f export_cellgrids.sql
\set ON_ERROR_STOP on
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';

CREATE TEMP TABLE Track AS
SELECT MMSI, atTime(TripLonLat, tstzspan '[2026-01-20 08:45:29+00, 2026-01-20 09:52:23+00]') AS Trip
FROM Ships WHERE MMSI = 219002732;
CREATE TEMP TABLE Mpa AS
SELECT Id, NameEng AS Name, GeomLonLat AS Geom FROM NaturalAreas WHERE Id = 17;

-- The frames in EPSG:25832, in the aspect 700:380 of the panels
CREATE TEMP TABLE Frame(Panel text PRIMARY KEY, Grid text, Res int, Geom geometry(Polygon, 25832));
INSERT INTO Frame
SELECT g || '_' || r, g, r, ST_MakeEnvelope(cx - 4000, cy - 2171, cx + 4000, cy + 2171, 25832)
FROM (SELECT (ST_XMin(e) + ST_XMax(e)) / 2 AS cx, (ST_YMin(e) + ST_YMax(e)) / 2 AS cy
      FROM (SELECT ST_Envelope(ST_Transform(trajectory(Trip), 25832)) e FROM Track) a) b,
  (VALUES ('h3', 8), ('quadbin', 15), ('s2', 14)) AS v(g, r);
-- The excerpt: the exit of the harbour, from the start of the track
INSERT INTO Frame
SELECT g || '_' || r, g, r, ST_MakeEnvelope(ST_X(p) - 600, ST_Y(p) - 1100, ST_X(p) + 1426, ST_Y(p), 25832)
FROM (SELECT ST_Transform(startValue(Trip), 25832) p FROM Track) a,
  (VALUES ('h3', 9), ('quadbin', 16), ('s2', 15)) AS v(g, r);

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

-- Panel | cells of the grid drawn | cells crossed | mean area of a crossed cell
SELECT f.Panel, (SELECT COUNT(*) FROM Grid g WHERE g.Panel = f.Panel) AS GridCells,
  COUNT(c.*) AS Crossed, AVG(c.Area) AS MeanArea
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
