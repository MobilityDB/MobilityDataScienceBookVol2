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

-- Case study, Traffic over a Global Grid: vessel-hours per H3 cell of resolution
-- 7 from the temporal cells of the trips, the roll-up to resolution 5, and the
-- depth of the water summarized over the cells as zones. The boundaries of the
-- cells are transformed once to EPSG:25832 when the table CellZones is built.
-- Each listing of the chapter is preceded by its printed answer; the other
-- queries give the numbers stated in the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Query: vessels and vessel-hours per H3 cell of resolution 7
/* Cell            | Vessels | VesselHours
   871f24a59ffffff |      64 |      1022.5
   871f3562cffffff |      42 |       730.3
   871f2414cffffff |      42 |       572.4 */
DROP TABLE IF EXISTS CellTraffic;
CREATE TABLE CellTraffic AS
SELECT u.value AS Cell, COUNT(DISTINCT s.MMSI) AS Vessels,
  SUM(duration(u.time)) AS VesselTime
FROM Ships s, unnest(th3index(s.TripLonLat, 7)) AS u
GROUP BY u.value;
SELECT Cell, Vessels,
  round(EXTRACT(EPOCH FROM VesselTime) / 3600, 1) AS VesselHours
FROM CellTraffic
ORDER BY VesselTime DESC
LIMIT 3;
\echo == cells crossed and vessel-hours (25990 | 38965)
SELECT COUNT(*) AS Cells, round(EXTRACT(EPOCH FROM SUM(VesselTime)) / 3600) AS VesselHours
FROM CellTraffic;

\echo == Query: vessel-hours of resolution 5 computed from the trips and rolled up from resolution 7
-- 1238 | 35 | 437 | 1137 | 38965 | 38965
DROP TABLE IF EXISTS CellTraffic5;
CREATE TABLE CellTraffic5 AS
SELECT u.value AS Cell, COUNT(DISTINCT s.MMSI) AS Vessels,
  SUM(duration(u.time)) AS VesselTime
FROM Ships s, unnest(th3index(s.TripLonLat, 5)) AS u
GROUP BY u.value;
WITH RollUp AS (
  SELECT cellToParent(Cell, 5) AS Cell, SUM(VesselTime) AS VesselTime,
    SUM(Vessels) AS VesselsSum
  FROM CellTraffic
  GROUP BY 1 )
SELECT COUNT(*) AS Cells,
  COUNT(*) FILTER (WHERE r.Cell IS NULL OR d.Cell IS NULL) AS OneSide,
  COUNT(*) FILTER (WHERE abs(EXTRACT(EPOCH FROM d.VesselTime -
    r.VesselTime)) > 0.05 * EXTRACT(EPOCH FROM d.VesselTime)) AS Differ,
  COUNT(*) FILTER (WHERE r.VesselsSum > d.Vessels) AS Overcount,
  round(EXTRACT(EPOCH FROM SUM(d.VesselTime)) / 3600) AS DirectHours,
  round(EXTRACT(EPOCH FROM SUM(r.VesselTime)) / 3600) AS RolledHours
FROM CellTraffic5 d FULL JOIN RollUp r USING (Cell);
\echo == among the cells whose two values differ by more than 100 vessel-hours, the largest ratio (851f26d3fffffff: 11.4 against 469.0)
WITH RollUp AS (
  SELECT cellToParent(Cell, 5) AS Cell, SUM(VesselTime) AS VesselTime
  FROM CellTraffic
  GROUP BY 1 )
SELECT Cell, round(EXTRACT(EPOCH FROM d.VesselTime) / 3600, 1) AS DirectHours,
  round(EXTRACT(EPOCH FROM r.VesselTime) / 3600, 1) AS RolledHours
FROM CellTraffic5 d JOIN RollUp r USING (Cell)
WHERE abs(EXTRACT(EPOCH FROM d.VesselTime - r.VesselTime)) > 100 * 3600
ORDER BY greatest(EXTRACT(EPOCH FROM d.VesselTime) / EXTRACT(EPOCH FROM r.VesselTime),
  EXTRACT(EPOCH FROM r.VesselTime) / EXTRACT(EPOCH FROM d.VesselTime)) DESC
LIMIT 1;
\echo == its child with the most vessel-hours, and the share of the child inside the parent (871f26d1bffffff: 458.2 h, 50.1%)
SELECT Cell, round(EXTRACT(EPOCH FROM VesselTime) / 3600, 1) AS VesselHours
FROM CellTraffic
WHERE cellToParent(Cell, 5) = '851f26d3fffffff'
ORDER BY VesselTime DESC
LIMIT 1;
SELECT round((100 * ST_Area(ST_Intersection(cellToBoundary(h3index '871f26d1bffffff'),
    cellToBoundary(h3index '851f26d3fffffff'))::geography) /
  ST_Area(cellToBoundary(h3index '871f26d1bffffff')::geography))::numeric, 1)
  AS PctInParent;

\echo == Query: vessel-hours by the mean depth of the H3 cells of resolution 7
/* MeanDepth | Cells | VesselHours
   < 10 m    |   918 |       13415
   10-20 m   |  2293 |        3736
   20-50 m   |  8012 |        4278
   >= 50 m   |  3503 |        2131
   no depth  | 11264 |       15404 */
DROP TABLE IF EXISTS CellZones, CellDepth;
CREATE TABLE CellZones AS
SELECT Cell, ST_Transform(cellToBoundary(Cell), 25832) AS Geom
FROM CellTraffic;
CREATE INDEX CellZones_Geom_Idx ON CellZones USING gist (Geom);
CREATE TABLE CellDepth AS
SELECT z.Cell, ST_SummaryStatsAgg(ST_Clip(b.Rast, z.Geom), 1, true) AS Depth
FROM CellZones z, Bathymetry b
WHERE ST_Intersects(b.Rast, z.Geom)
GROUP BY z.Cell;
SELECT CASE WHEN (d.Depth).count IS NULL OR (d.Depth).count = 0
    THEN 'no depth'
    WHEN (d.Depth).mean < 10 THEN '< 10 m'
    WHEN (d.Depth).mean < 20 THEN '10-20 m'
    WHEN (d.Depth).mean < 50 THEN '20-50 m'
    ELSE '>= 50 m' END AS MeanDepth,
  COUNT(*) AS Cells,
  round(SUM(EXTRACT(EPOCH FROM t.VesselTime)) / 3600) AS VesselHours
FROM CellTraffic t LEFT JOIN CellDepth d USING (Cell)
GROUP BY 1
ORDER BY MIN(COALESCE((d.Depth).mean, 1e9));
\echo == cells with a mean depth of less than 10 m that meet a port area, and their vessel-hours (169 | 10400)
SELECT COUNT(*) AS Cells, round(SUM(EXTRACT(EPOCH FROM t.VesselTime)) / 3600) AS VesselHours
FROM CellTraffic t JOIN CellDepth d USING (Cell) JOIN CellZones z USING (Cell)
WHERE (d.Depth).mean < 10 AND EXISTS (SELECT 1 FROM Port p WHERE ST_Intersects(p.Geom, z.Geom));
\echo == mean depth of the three busiest cells (6.3, 3.3, 8.4)
SELECT t.Cell, round((d.Depth).mean::numeric, 1) AS MeanDepth
FROM CellTraffic t JOIN CellDepth d USING (Cell)
ORDER BY t.VesselTime DESC
LIMIT 3;

\echo == Listing: the cells crossed by most vessels and the depth in them
-- Ties are broken by the text of the cell, whose order is that of the identifiers: the btree
-- operator class of h3index of h3-pg 4.2.3 sorts the identifiers in descending order.
/* Cell            | Vessels | MeanDepth | MinDepth
   871f22252ffffff |      78 |      36.3 |     17.7
   871f2226dffffff |      78 |      36.9 |     19.9
   871f23c9effffff |      77 |      33.7 |     15.3
   871f22268ffffff |      76 |      36.2 |     17.7
   871f23c9cffffff |      75 |      31.7 |     21.4 */
SELECT t.Cell, t.Vessels, round((d.Depth).mean::numeric, 1) AS MeanDepth,
  round((d.Depth).min::numeric, 1) AS MinDepth
FROM CellTraffic t JOIN CellDepth d USING (Cell) JOIN CellZones z USING (Cell)
WHERE (d.Depth).count * 2500 >= 0.95 * ST_Area(z.Geom)
ORDER BY t.Vessels DESC, t.Cell::text
LIMIT 5;
