-- Section 3, the spatial-database answer: the depth read at each reported
-- position of the vessel, and the runs of consecutive reports over water less
-- than 20 m deep.
\pset footer off
\timing on
WITH Positions AS (
  SELECT a.T, ST_Value(b.Rast, ST_Transform(a.Geom, 3034)) AS Depth
  FROM AISClean a JOIN Bathymetry b
    ON ST_Intersects(b.Rast, ST_Transform(a.Geom, 3034))
  WHERE a.MMSI = 273277840 ),
Flags AS (
  SELECT T, Depth < 20 AS Shallow,
    LAG(Depth < 20) OVER (ORDER BY T) AS PrevShallow
  FROM Positions
  WHERE Depth IS NOT NULL ),
Runs AS (
  SELECT T, Shallow,
    SUM(CASE WHEN Shallow IS DISTINCT FROM PrevShallow THEN 1 ELSE 0 END)
      OVER (ORDER BY T) AS Run
  FROM Flags )
SELECT min(T) AS FirstReport, max(T) AS LastReport, count(*) AS Reports
FROM Runs
WHERE Shallow
GROUP BY Run
ORDER BY FirstReport;

\echo == reports of the vessel over the model, and their spacing
SELECT count(*) AS Reports,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY Gap) AS MedianGap, max(Gap) AS MaxGap
FROM (
  SELECT EXTRACT(EPOCH FROM T - LAG(T) OVER (ORDER BY T)) AS Gap
  FROM AISClean WHERE MMSI = 273277840 ) t;
