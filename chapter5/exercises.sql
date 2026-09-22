-- Exercises of the chapter Rasters and Temporal Tessellations, run on the
-- database of the case study.
\pset footer off
\timing on
SET TimeZone = 'UTC';

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
LIMIT 5;

\echo == 3. time-weighted average surface temperature met by the first 200 vessels
SELECT s.MMSI, round(twAvg(mergeAgg(rasterValue(atTime(s.Trip, t.ValidTime), t.Rast)
    ORDER BY t.ValidTime))::numeric, 2) AS AvgTemp
FROM Ships200 s, SurfaceTemperature t
WHERE s.Trip && t.ValidTime AND ST_Intersects(t.Rast, trajectory(s.Trip))
GROUP BY s.MMSI
ORDER BY AvgTemp
LIMIT 5;

\echo == 4. distinct vessels per QUADBIN tile of zoom 10 among the first 200 vessels
SELECT u.value AS Tile, count(DISTINCT s.MMSI) AS Vessels
FROM Ships200 s, unnest(tquadbin(s.TripLonLat, 10)) AS u
GROUP BY u.value
ORDER BY Vessels DESC
LIMIT 5;

\echo == 5. cells of H3 resolution 7 crossed by exactly one of the first 200 vessels
SELECT count(*) AS Cells, count(*) FILTER (WHERE Vessels = 1) AS OneVessel
FROM (
  SELECT u.value AS Cell, count(DISTINCT s.MMSI) AS Vessels
  FROM Ships200 s, unnest(th3index(s.TripLonLat, 7)) AS u
  GROUP BY u.value ) t;
