-- Sections 5 and 6: global grids and temporal cells, on a position and a short
-- trip in the Kattegat off Frederikshavn.
\pset footer off

\echo == the cell of one position on each grid, and its area in km2
WITH p AS (SELECT geometry 'SRID=4326;Point(10.60 57.44)' AS g)
SELECT r AS res,
  latLngToCell(g, r) AS h3,
  round((cellArea(latLngToCell(g, r)) / 1e6)::numeric, 3) AS h3_km2
FROM p, generate_series(6, 9) AS r;

WITH p AS (SELECT geometry 'SRID=4326;Point(10.60 57.44)' AS g)
SELECT z AS zoom,
  geoToQuadbinCell(g, z) AS quadbin,
  round((cellArea(geoToQuadbinCell(g, z)) / 1e6)::numeric, 3) AS qb_km2,
  quadbinCellToTile(geoToQuadbinCell(g, z)) AS tile,
  quadbinCellToQuadkey(geoToQuadbinCell(g, z)) AS quadkey
FROM p, generate_series(12, 15) AS z;

WITH p AS (SELECT geography 'SRID=4326;Point(10.60 57.44)' AS g)
SELECT l AS level,
  geoToS2Cell(g, l) AS s2,
  s2CellToToken(geoToS2Cell(g, l)) AS token,
  round((cellArea(geoToS2Cell(g, l)) / 1e6)::numeric, 3) AS s2_km2
FROM p, generate_series(13, 16) AS l;

\echo == identifier ranges: descendants of an S2 cell lie between two identifiers
WITH c AS (SELECT geoToS2Cell(geography 'SRID=4326;Point(10.60 57.44)', 13) AS c)
SELECT c, s2RangeMin(c) AS range_min, s2RangeMax(c) AS range_max,
  s2CellContains(c, geoToS2Cell(geography 'SRID=4326;Point(10.60 57.44)', 20)) AS contains_child
FROM c;

\echo == a trip lifted to each grid
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT th3index(trip, 7) AS h3_res7 FROM t;

WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT tquadbin(trip, 13) AS qb_zoom13 FROM t;

WITH t AS (
  SELECT tgeogpoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT ts2cell(trip, 13) AS s2_level13 FROM t;

\echo == instants versus the walk: cells of the two reported positions only
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT numValues(getValues(th3index(trip, 8))) AS walk_cells,
  (SELECT count(DISTINCT latLngToCell(getValue(i), 8)) FROM unnest(instants(trip)) AS i) AS instant_cells
FROM t;

\echo == time spent in each cell
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT u.value AS cell, duration(u.time) AS time_in_cell
FROM t, unnest(th3index(trip, 7)) AS u
ORDER BY startTimestamp(u.time);

\echo == restriction to a set of cells
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT whenTrue(th3index(trip, 7) #= h3index '871f24270ffffff') AS in_cell,
  atValues(th3index(trip, 7), h3indexset '{871f24270ffffff, 871f24271ffffff}') AS at_cells
FROM t;

\echo == roll-up: parents of the fine path versus the coarse path
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT getValues(cellToParent(th3index(trip, 9), 7)) AS h3_parents_of_res9,
  getValues(th3index(trip, 7)) AS h3_res7
FROM t;

WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS trip)
SELECT getValues(cellToParent(tquadbin(trip, 15), 13)) = getValues(tquadbin(trip, 13))
  AS quadbin_parents_equal
FROM t;
