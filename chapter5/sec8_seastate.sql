-- Section 8: significant wave height met by each vessel along its trip, from
-- the hourly WaveHeight rasters, each step held constant during its hour.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS SeaState;
CREATE TABLE SeaState AS
SELECT s.MMSI, mergeAgg(rasterValue(atTime(s.Trip, w.ValidTime), w.Rast)
  ORDER BY w.ValidTime) AS WaveHeight
FROM Ships s, WaveHeight w
WHERE s.Trip && w.ValidTime AND ST_Intersects(w.Rast, trajectory(s.Trip))
GROUP BY s.MMSI;

\echo == vessels, and those that met waves of at least 1, 1.5, 2 and 2.5 m
SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE maxValue(WaveHeight) >= 1) AS Over1,
  count(*) FILTER (WHERE maxValue(WaveHeight) >= 1.5) AS Over15,
  count(*) FILTER (WHERE maxValue(WaveHeight) >= 2) AS Over2,
  count(*) FILTER (WHERE maxValue(WaveHeight) >= 2.5) AS Over25,
  round(max(maxValue(WaveHeight))::numeric, 2) AS MaxHs
FROM SeaState;

\echo == the vessels longest in waves of at least 2 m
SELECT MMSI, round(maxValue(WaveHeight)::numeric, 2) AS MaxHs,
  duration(whenTrue(WaveHeight #>= 2)) AS Over2
FROM SeaState
WHERE maxValue(WaveHeight) >= 2
ORDER BY duration(whenTrue(WaveHeight #>= 2)) DESC
LIMIT 10;
