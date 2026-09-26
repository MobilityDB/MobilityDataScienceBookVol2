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
SELECT s.MMSI, round(maxValue(w.WaveHeight)::numeric, 2) AS MaxHs,
  startTimestamp(atMax(w.WaveHeight)) AS AtTime
FROM Ships200 s JOIN SeaState w USING (MMSI)
ORDER BY maxValue(w.WaveHeight) DESC NULLS LAST
LIMIT 3;

\echo == 3. time-weighted average surface temperature met by the first 200 vessels
SELECT s.MMSI, round(twAvg(mergeAgg(rasterValue(atTime(s.Trip, t.ValidTime), t.Rast)
    ORDER BY t.ValidTime))::numeric, 2) AS AvgTemp
FROM Ships200 s, SurfaceTemperature t
WHERE s.Trip && t.ValidTime AND ST_Intersects(t.Rast, trajectory(s.Trip))
GROUP BY s.MMSI
ORDER BY AvgTemp, s.MMSI
LIMIT 3;

\echo == 4. distinct vessels per QUADBIN tile of zoom 10 among the first 200 vessels
SELECT u.value AS Tile, count(DISTINCT s.MMSI) AS Vessels
FROM Ships200 s, unnest(tquadbin(s.TripLonLat, 10)) AS u
GROUP BY u.value
ORDER BY Vessels DESC, Tile
LIMIT 3;

\echo == 5. cells of H3 resolution 7 crossed by exactly one of the first 200 vessels
SELECT count(*) AS Cells, count(*) FILTER (WHERE Vessels = 1) AS OneVessel
FROM (
  SELECT u.value AS Cell, count(DISTINCT s.MMSI) AS Vessels
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
SELECT to_char(lower(ValidTime), 'HH24:MI') AS Hour,
  sum((ST_SummaryStats(ST_Reclass(Rast, 1, '[2-100]:1', '8BUI', 0))).count) AS Km2
FROM WaveHeight
GROUP BY lower(ValidTime)
ORDER BY Km2 DESC
LIMIT 3;
