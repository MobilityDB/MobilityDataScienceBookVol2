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

-- From PostGIS to MobilityDB: the depth under the vessel 273277840 along its
-- voyage, first with PostGIS alone at the reported positions and then with
-- MobilityDB along the movement. Every table is in EPSG:25832, so no query
-- transforms a geometry. Each listing of the chapter is preceded by its printed
-- answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == the vessel: reported draught, reports, and length of its trip (14.9 m, 512 km)
SELECT MMSI, MAX(Draught) AS Draught, MIN(T) AS FirstReport, MAX(T) AS LastReport,
  COUNT(*) AS Reports
FROM AISClean WHERE MMSI = 273277840 GROUP BY MMSI;
SELECT round((length(Trip) / 1000)::numeric, 1) AS Km FROM Ships WHERE MMSI = 273277840;

\echo == Listing: using a spatial database (nine periods)
/* FirstReport         | LastReport
   2026-01-20 01:28:10 | 2026-01-20 01:28:39
   2026-01-20 01:28:59 | 2026-01-20 01:28:59
   2026-01-20 07:01:59 | 2026-01-20 07:03:28
   ...
   2026-01-20 08:48:50 | 2026-01-20 08:49:09 */
WITH Positions AS (
  SELECT a.T, ST_Value(b.Rast, a.Geom) AS Depth
  FROM AISClean a, Bathymetry b
  WHERE a.MMSI = 273277840 AND ST_Intersects(b.Rast, a.Geom) ),
Flags AS (
  SELECT T, Depth < 20 AS Shallow,
    LAG(Depth < 20) OVER (ORDER BY T) AS PrevShallow
  FROM Positions ),
Runs AS (
  SELECT T, Shallow,
    SUM(CASE WHEN Shallow IS DISTINCT FROM PrevShallow THEN 1 ELSE 0 END)
      OVER (ORDER BY T) AS Run
  FROM Flags )
SELECT MIN(T) AS FirstReport, MAX(T) AS LastReport
FROM Runs
WHERE Shallow
GROUP BY Run
ORDER BY FirstReport;

\echo == Listing: using a mobility database (thirteen periods, 00:10:21.567055)
/* {[2026-01-20 01:27:49.285823, 2026-01-20 01:27:49.6816),
    [2026-01-20 01:27:59.256121, 2026-01-20 01:28:04.705125),
    [2026-01-20 01:28:09.322936, 2026-01-20 01:28:19.225736),
    [2026-01-20 01:28:19.520816, 2026-01-20 01:28:46.708854), ...,
    [2026-01-20 08:48:43.108411, 2026-01-20 08:49:16.5474)} | 00:10:21.567055 */
WITH VesselDepth AS (
  SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, Bathymetry b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip))
  GROUP BY s.MMSI )
SELECT whenTrue(Depth #< 20) AS Periods,
  duration(whenTrue(Depth #< 20)) AS Total
FROM VesselDepth;

\echo == length of the trip restricted to the thirteen periods (3287.0 m)
WITH VesselDepth AS (
  SELECT s.Trip, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, Bathymetry b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip))
  GROUP BY s.Trip )
SELECT round(length(atTime(Trip, whenTrue(Depth #< 20)))::numeric, 1) AS Meters
FROM VesselDepth;
