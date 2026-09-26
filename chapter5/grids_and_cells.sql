-- Discrete Global Grid Systems and Temporal Cells: the cells of a position on
-- H3, QUADBIN, and S2, the order of their identifiers, the cells of a trip, and
-- what an answer computed on cells guarantees, on the first 200 vessels of the
-- day (table Ships200). The listings of the chapter omit the SRID (4326) of the
-- trip and the date of the timestamps. Each listing is preceded by its printed
-- answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Listing: the cell of a position near Frederikshavn on each grid
/* 7 | 871f24272ffffff | 3.979
   8 | 881f24272bfffff | 0.568
   9 | 891f24272b7ffff | 0.081 */
SELECT r, latLngToCell(geometry 'SRID=4326;Point(10.60 57.44)', r) AS H3,
  round((cellArea(latLngToCell(geometry 'SRID=4326;Point(10.60 57.44)', r))
    / 1e6)::numeric, 3) AS Km2
FROM generate_series(7, 9) AS r;
/* 13 | 48d60b7e2fffffff | {4337,2491,13}
   14 | 48e60b7e2cffffff | {8674,4982,14}
   15 | 48f60b7e2c3fffff | {17348,9964,15} */
SELECT z, geoToQuadbinCell(geometry 'SRID=4326;Point(10.60 57.44)', z) AS Quadbin,
  quadbinCellToTile(geoToQuadbinCell(geometry 'SRID=4326;Point(10.60 57.44)', z))
FROM generate_series(13, 15) AS z;
/* 13 | 464f3c4c
   14 | 464f3c4f
   15 | 464f3c4ec */
SELECT l, s2CellToToken(geoToS2Cell(geography 'SRID=4326;Point(10.60 57.44)', l))
FROM generate_series(13, 15) AS l;

\echo == areas of the QUADBIN cell of zoom 13 and of the cells closest in area (6.919, 0.432, 0.318 km2)
SELECT round((cellArea(geoToQuadbinCell(geometry 'SRID=4326;Point(10.60 57.44)', 13))
    / 1e6)::numeric, 3) AS Quadbin13,
  round((cellArea(geoToQuadbinCell(geometry 'SRID=4326;Point(10.60 57.44)', 15))
    / 1e6)::numeric, 3) AS Quadbin15,
  round((cellArea(geoToS2Cell(geography 'SRID=4326;Point(10.60 57.44)', 14))
    / 1e6)::numeric, 3) AS S2Level14;

\echo == Listing: the descendants of an S2 cell lie between two identifiers
-- 464f3c4800000001 | 464f3c4fffffffff
SELECT s2RangeMin(c), s2RangeMax(c)
FROM (SELECT geoToS2Cell(geography 'SRID=4326;Point(10.60 57.44)', 13) AS c) t;

\echo == Listing: the H3 cells of resolution 7 of a trip
/* [871f2420dffffff@08:00:00, 871f24272ffffff@08:02:07.801206,
   871f24270ffffff@08:08:00.339359, 871f24271ffffff@08:13:56.99568,
   871f24262ffffff@08:21:49.166915, 871f24244ffffff@08:21:55.446083,
   871f24263ffffff@08:26:25.301364, 871f24263ffffff@08:30:00] */
SELECT th3index(tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
  SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]', 7);

\echo == cells of the trip: H3 resolution 8 crossed (16) against the cells of its two positions (2), QUADBIN 13 (6), S2 13 (12)
WITH t AS (
  SELECT tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
    SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]' AS Trip )
SELECT numValues(getValues(th3index(Trip, 8))) AS H3r8Crossed,
  (SELECT count(DISTINCT latLngToCell(getValue(i), 8)) FROM unnest(instants(Trip)) i)
    AS H3r8Positions,
  numValues(getValues(tquadbin(Trip, 13))) AS Quadbin13,
  numValues(getValues(ts2cell(Trip::tgeogpoint, 13))) AS S2Level13
FROM t;

\echo == Listing: time spent in each cell (seven cells, 30 minutes in total)
/* 871f2420dffffff | 00:02:07.801206
   871f24272ffffff | 00:05:52.538153
   ...
   871f24263ffffff | 00:03:34.698636 */
SELECT u.value AS Cell, duration(u.time) AS TimeInCell
FROM unnest(th3index(tgeompoint '[SRID=4326;Point(10.56 57.43)@2025-01-01 08:00,
  SRID=4326;Point(10.70 57.47)@2025-01-01 08:30]', 7)) AS u
ORDER BY startTimestamp(u.time);

\echo == the first 200 vessels of the day in the order of their MMSI, and the protected areas in longitude and latitude
DROP TABLE IF EXISTS Ships200;
CREATE TABLE Ships200 AS SELECT * FROM Ships ORDER BY MMSI LIMIT 200;
ALTER TABLE NaturalAreas ADD COLUMN IF NOT EXISTS GeomLonLat geometry;
UPDATE NaturalAreas SET GeomLonLat = ST_Transform(Geom, 4326);

\echo == Listing: cells as a filter for the marine protected areas
-- 550 | 60 | 119 | 0
SELECT count(*) AS Pairs, count(*) FILTER (WHERE TripMeets) AS TripMeets,
  count(*) FILTER (WHERE CellsMeet) AS CellsMeet,
  count(*) FILTER (WHERE TripMeets AND NOT CellsMeet) AS TripOnly
FROM (
  SELECT eIntersects(s.TripLonLat, n.GeomLonLat) AS TripMeets,
    eIntersects(th3index(s.TripLonLat, 7), n.GeomLonLat) AS CellsMeet
  FROM Ships200 s, NaturalAreas n
  WHERE n.Realm IN ('Marine', 'Coastal') AND
    s.TripLonLat && stbox(n.GeomLonLat) ) t;

\echo == Listing: parents of the cells at a finer resolution against the cells at the coarser one
-- 30 | 0
SELECT count(*) FILTER (WHERE (getValues(th3index(TripLonLat, 7)) -
    getValues(cellToParent(th3index(TripLonLat, 9), 7))) IS NOT NULL) AS H3Missed,
  count(*) FILTER (WHERE getValues(tquadbin(TripLonLat, 13)) <>
    getValues(cellToParent(tquadbin(TripLonLat, 15), 13))) AS QuadbinDiffer
FROM Ships200;
