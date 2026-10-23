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

-- Exercises of the chapter Rasters and Temporal Tessellations, run on the
-- database of the case study after the scripts of the sections. The last
-- exercise, the vegetation index of a Landsat 8 scene of the reader's choice,
-- has its answer in the chapter and needs no table of this database.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == 1. time during which vessel 273277840 sailed over water between 20 and 30 m deep
WITH VesselDepth AS (
  SELECT mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, Bathymetry b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) )
SELECT duration(whenTrue((Depth #>= 20) & (Depth #< 30))) AS Duration
FROM VesselDepth;

\echo == 2. for each of the first 200 vessels, the highest wave met and when
SELECT s.MMSI, round(maxValue(w.WaveHeight), 2) AS MaxHs,
  startTimestamp(atMax(w.WaveHeight)) AS AtTime
FROM Ships200 s JOIN SeaState w USING (MMSI)
ORDER BY maxValue(w.WaveHeight) DESC NULLS LAST
LIMIT 3;

\echo == 3. time-weighted average surface temperature met by the first 200 vessels
SELECT s.MMSI, round(twAvg(mergeAgg(rasterValue(atTime(s.Trip, t.ValidTime), t.Rast)
    ORDER BY t.ValidTime)), 2) AS AvgTemp
FROM Ships200 s, SurfaceTemperature t
WHERE s.Trip && t.ValidTime AND ST_Intersects(t.Rast, trajectory(s.Trip))
GROUP BY s.MMSI
ORDER BY AvgTemp, s.MMSI
LIMIT 3;

\echo == 4. distinct vessels per QUADBIN tile of zoom 10 among the first 200 vessels
SELECT u.value AS Tile, COUNT(DISTINCT s.MMSI) AS Vessels
FROM Ships200 s, unnest(tquadbin(s.TripLonLat, 10)) AS u
GROUP BY u.value
ORDER BY Vessels DESC, Tile
LIMIT 3;

\echo == 5. cells of H3 resolution 7 crossed by exactly one of the first 200 vessels
SELECT COUNT(*) AS Cells, COUNT(*) FILTER (WHERE Vessels = 1) AS OneVessel
FROM (
  SELECT u.value AS Cell, COUNT(DISTINCT s.MMSI) AS Vessels
  FROM Ships200 s, unnest(th3index(s.TripLonLat, 7)) AS u
  GROUP BY u.value ) t;

\echo == 6. directions faced by the slopes of at least 1 degree of the seabed of the reef area (Seabed of map_algebra.sql)
SELECT v.value AS Direction, round(v.count * 0.0025, 2) AS Km2
FROM Seabed s, ST_ValueCount(ST_Reclass(ST_Clip(ST_MapAlgebra(
    ST_Aspect(s.Rast, 1, '32BF', 'DEGREES'), 1,
    ST_Slope(s.Rast, 1, '32BF', 'DEGREES', 1.0), 1,
    'CASE WHEN [rast2] < 1 THEN 0 ELSE [rast1] END', '32BF'), s.Geom),
  1, '[0-0]:0, (0-45):1, [45-135):2, [135-225):3, [225-315):4, [315-360]:1',
  '8BUI', 255)) v
ORDER BY v.value;
\echo == 7. hours with the largest area of the sea with waves of at least 2 m
SELECT to_char(lower(ValidTime), 'HH24:MI') AS ValidHour,
  SUM((ST_SummaryStats(ST_Reclass(Rast, 1, '[2-100]:1', '8BUI', 0))).count) AS Km2
FROM WaveHeight
GROUP BY lower(ValidTime)
ORDER BY Km2 DESC
LIMIT 3;

-- Exercise 5.2, answered by hand and verified on the raster Depth of
-- map_algebra.sql; the numbers of Exercise 5.3 are computed by grids_by_hand.py
\echo == 8. the depths of the raster Depth in three classes
SELECT ST_DumpValues(ST_Reclass(Rast, 1, '[0-10):1, [10-16):2, [16-100]:3',
  '8BUI', 0), 1)
FROM Depth;

\echo == 9. the focal maximum of the raster Depth over windows of 3 x 3 pixels
SELECT ST_DumpValues(ST_MapAlgebra(Rast, 1,
  'ST_Max4ma(double precision[][][], integer[][], text[])'::regprocedure,
  '32BF', 'FIRST', NULL, 1, 1), 1)
FROM Depth;

\echo == 10. the bilinear and the nearest depth at the position (600225, 6400175)
SELECT ST_Value(Rast, 1, geometry 'SRID=25832;Point(600225 6400175)', true,
  'bilinear') AS Bilinear,
  ST_Value(Rast, 1, geometry 'SRID=25832;Point(600225 6400175)') AS Nearest
FROM Depth;
