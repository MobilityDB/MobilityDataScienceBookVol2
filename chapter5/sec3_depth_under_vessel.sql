-- Section 3: the depth under a deep-draught vessel along its voyage. Every table
-- is in EPSG:25832 after preprocessing, so no query transforms a geometry.
\pset footer off
\timing on

\echo == MobilityDB: the depth under the vessel, read from the tiles its trip crosses
DROP TABLE IF EXISTS VesselDepth;
CREATE TABLE VesselDepth AS
SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
FROM Ships s, Bathymetry b
WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip))
GROUP BY s.MMSI;

SELECT numInstants(Depth) AS Instants, numSequences(Depth) AS Sequences,
  round(minValue(Depth)::numeric, 1) AS MinDepth, duration(Depth) AS OverModel,
  duration(whenTrue(Depth #< 20)) AS Under20
FROM VesselDepth;
SELECT whenTrue(Depth #< 20) AS Periods FROM VesselDepth;

\echo == PostGIS only: the depth at each reported position, runs of shallow reports
WITH Positions AS (
  SELECT a.T, ST_Value(b.Rast, a.Geom) AS Depth
  FROM AISClean a JOIN Bathymetry b ON ST_Intersects(b.Rast, a.Geom)
  WHERE a.MMSI = 273277840 ),
Flags AS (
  SELECT T, Depth < 20 AS Shallow, LAG(Depth < 20) OVER (ORDER BY T) AS PrevShallow
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

\echo == reports of the vessel and their spacing in seconds
SELECT count(*) AS Reports,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY Gap) AS MedianGap, max(Gap) AS MaxGap
FROM (
  SELECT EXTRACT(EPOCH FROM T - LAG(T) OVER (ORDER BY T)) AS Gap
  FROM AISClean WHERE MMSI = 273277840 ) t;
