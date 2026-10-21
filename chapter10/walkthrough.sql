-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 10: Mobility Data Pipelines
--
-- Sect. "Running a Query over a Layout": Query 1 (the vessels that called at both the
-- Rodby and the Puttgarden ferry ports) over the window of one day starting at 08:00 UTC on
-- 15 January 2026, followed step by step over the layout L3 and over L0
--
-- ${LAKEHOUSE_RUN} is the run directory that benchmark/reproduce.sh of MobilityLakehouse
-- writes for January 2026 (data/stage/planar/2026-01-01_2026-02-01), holding L0/ and
-- layouts_daily/L3/. Run with the DuckDB v1.5.5 shell through envsubst, as the README says.
-------------------------------------------------------------------------------
.bail on
.mode markdown
INSTALL spatial FROM core_nightly;
LOAD spatial;
LOAD '${MOBILITYDUCK_EXTENSION}';
SET TimeZone = 'UTC';

-- The two ports and the window, as printed in the chapter
CREATE TEMP TABLE Ports(Port, XMin, YMin, XMax, YMax) AS VALUES
  ('Rodby', 651135, 6058230, 651422, 6058548),
  ('Puttgarden', 644339, 6042108, 644896, 6042487);
CREATE TEMP TABLE Win(T0, T1, D0, D1) AS VALUES
  (TIMESTAMP '2026-01-15 08:00:00', TIMESTAMP '2026-01-16 08:00:00',
   DATE '2026-01-15', DATE '2026-01-16');

-- The bounds of every file of a layout, from the statistics of its row groups: what the
-- manifests of the catalog record for a file, and the footer of the file for a row group
CREATE TEMP TABLE Files AS
SELECT Layout, file_name AS File, COUNT(DISTINCT row_group_id) AS RowGroups,
  SUM(row_group_num_rows) FILTER (WHERE path_in_schema = 'trip_xmin') AS NoRows,
  MIN(TRY_CAST(stats_min AS DOUBLE)) FILTER (WHERE path_in_schema = 'trip_xmin') AS XMin,
  MAX(TRY_CAST(stats_max AS DOUBLE)) FILTER (WHERE path_in_schema = 'trip_xmax') AS XMax,
  MIN(TRY_CAST(stats_min AS DOUBLE)) FILTER (WHERE path_in_schema = 'trip_ymin') AS YMin,
  MAX(TRY_CAST(stats_max AS DOUBLE)) FILTER (WHERE path_in_schema = 'trip_ymax') AS YMax,
  MIN(TRY_CAST(stats_min AS TIMESTAMP)) FILTER (WHERE path_in_schema = 'trip_tmin') AS TMin,
  MAX(TRY_CAST(stats_max AS TIMESTAMP)) FILTER (WHERE path_in_schema = 'trip_tmax') AS TMax
FROM (
  SELECT 'L3' AS Layout, * FROM parquet_metadata('${LAKEHOUSE_RUN}/layouts_daily/L3/day-*/**/*.parquet')
  UNION ALL
  SELECT 'L0' AS Layout, * FROM parquet_metadata('${LAKEHOUSE_RUN}/L0/year=*/month=*/day-*.parquet') )
GROUP BY Layout, file_name;
CREATE TEMP TABLE FileBytes AS
SELECT filename AS File, size AS Bytes FROM read_blob('${LAKEHOUSE_RUN}/layouts_daily/L3/day-*/**/*.parquet')
UNION ALL
SELECT filename, size FROM read_blob('${LAKEHOUSE_RUN}/L0/year=*/month=*/day-*.parquet');

.print == Step 1: the files of each layout, those whose time bounds meet the window, and those
.print == whose bounds also meet the box of each port
SELECT f.Layout, COUNT(*) AS NoFiles,
  COUNT(*) FILTER (WHERE f.TMin <= w.T1 AND f.TMax >= w.T0) AS InWindow
FROM Files f, Win w GROUP BY f.Layout ORDER BY f.Layout;
CREATE TEMP TABLE Kept AS
SELECT f.Layout, p.Port, f.File, f.RowGroups, f.NoRows
FROM Files f, Win w, Ports p
WHERE f.TMin <= w.T1 AND f.TMax >= w.T0 AND
  f.XMin <= p.XMax AND f.XMax >= p.XMin AND f.YMin <= p.YMax AND f.YMax >= p.YMin;
SELECT k.Layout, k.Port, replace(k.File, '${LAKEHOUSE_RUN}/', '') AS FilePath,
  k.RowGroups, k.NoRows
FROM Kept k ORDER BY k.Layout, k.Port, k.File;
.print == The bytes of the files kept, as a share of the bytes of the layout
SELECT k.Layout, k.Port, round(100.0 * SUM(b.Bytes) / (SELECT SUM(c.Bytes) FROM FileBytes c
    WHERE (k.Layout = 'L3') = (c.File LIKE '%/layouts_daily/L3/%')), 2) AS PctBytes
FROM Kept k JOIN FileBytes b USING (File) GROUP BY k.Layout, k.Port ORDER BY k.Layout, k.Port;

.print == Steps 3 to 5: the rows of the files kept, those whose own box and time span meet the
.print == port and the window, those whose trajectory is in the port during the window, the vessels
.print == they belong to, and the most rows of one vessel
SET VARIABLE KeptFiles = (SELECT list(DISTINCT File) FROM Kept);
CREATE TEMP TABLE Rows AS
SELECT k.Layout, k.Port, r.MMSI,
  r.trip_xmin <= p.XMax AND r.trip_xmax >= p.XMin AND r.trip_ymin <= p.YMax AND
    r.trip_ymax >= p.YMin AND r.trip_tmin <= w.T1 AND r.trip_tmax >= w.T0 AND
    r.dt BETWEEN w.D0 AND w.D1 AS PassMBB,
  r.trip, p.XMin, p.YMin, p.XMax, p.YMax
FROM Kept k JOIN read_parquet(getvariable('KeptFiles'), filename = true, union_by_name = true) r ON r.filename = k.File, Ports p, Win w
WHERE p.Port = k.Port;
CREATE TEMP TABLE Refined AS
SELECT Layout, Port, MMSI
FROM Rows
WHERE PassMBB AND atStbox(tgeompointFromEWKB(trip), stbox('SRID=25832;STBOX XT(((' ||
  XMin || ',' || YMin || '),(' || XMax || ',' || YMax ||
  ')),[2026-01-15 08:00:00+00,2026-01-16 08:00:00+00])')) IS NOT NULL;
SELECT r.Layout, r.Port, COUNT(*) AS RowsRead, COUNT(*) FILTER (WHERE PassMBB) AS PassMBB,
  (SELECT COUNT(*) FROM Refined f WHERE f.Layout = r.Layout AND f.Port = r.Port) AS PassRefinement,
  (SELECT COUNT(DISTINCT MMSI) FROM Refined f WHERE f.Layout = r.Layout AND f.Port = r.Port)
    AS NoVessels,
  (SELECT MAX(n) FROM (SELECT COUNT(*) AS n FROM Refined f
    WHERE f.Layout = r.Layout AND f.Port = r.Port GROUP BY MMSI)) AS MaxRowsOneVessel
FROM Rows r GROUP BY r.Layout, r.Port ORDER BY r.Layout, r.Port;
.print == The answer: the vessels found at both ports
SELECT a.Layout, COUNT(DISTINCT a.MMSI) AS NoBoth
FROM Refined a JOIN Refined b ON a.Layout = b.Layout AND a.MMSI = b.MMSI
WHERE a.Port = 'Rodby' AND b.Port = 'Puttgarden'
GROUP BY a.Layout ORDER BY a.Layout;
