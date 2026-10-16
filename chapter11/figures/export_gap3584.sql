-- The data of the figure of the gap 3584 of the use case of chapter 11, read by fig_gap3584.py:
-- the one-minute positions of its window (tp.csv), the AIS reports of the vessel from 15 minutes
-- before the gap to 15 minutes after it (obs.csv), the reconstructions of the models crossdomain and
-- coordinates and of the baseline linear (rec.csv), and the positions fixed for each task
-- (masks.csv). The times are written in the time zone of Denmark, in which the figure gives them.
-- The script then prints the values the chapter quotes for this gap: the rows of the table
-- Reconstructed it shows, the errors of the positions 12 (recovery) and 13 to 15 (prediction), the
-- median recovery error before and after the gap, and the distance of the positions that each model
-- places inside the gap to the segment between the reports 15 and 28 that bound it.
--
--   psql -d ais -f export_gap3584.sql

\set ON_ERROR_STOP on
SET TimeZone = 'Europe/Brussels';

\copy (SELECT p.PointIdx, p.T, p.InGap, ST_X(p.Geom) AS x, ST_Y(p.Geom) AS y, p.T IN (g.TStart, g.TEnd) AS bound FROM TripPoints p JOIN Gaps g USING (GapId) WHERE GapId = 3584 ORDER BY p.PointIdx) TO 'tp.csv' CSV HEADER
\copy (SELECT c.T AT TIME ZONE 'UTC' AS t, ST_X(c.Geom) AS x, ST_Y(c.Geom) AS y, c.SOG AS sog, c.COG AS cog FROM AISClean c JOIN Gaps g USING (MMSI) WHERE g.GapId = 3584 AND (c.T AT TIME ZONE 'UTC') BETWEEN g.TStart - interval '15 minutes' AND g.TEnd + interval '15 minutes' ORDER BY c.T) TO 'obs.csv' CSV HEADER
\copy (SELECT Model, Task, PointIdx, ST_X(Geom) AS x, ST_Y(Geom) AS y FROM Reconstructed WHERE GapId = 3584 AND Model IN ('coordinates', 'crossdomain', 'linear') ORDER BY Model, Task, PointIdx) TO 'rec.csv' CSV HEADER
\copy (SELECT Task, PointIdx FROM EvalMasks WHERE GapId = 3584 ORDER BY Task, PointIdx) TO 'masks.csv' CSV HEADER

\echo The rows of Reconstructed shown for the gap 3584 (EPSG:25832)
SELECT Model, Task, PointIdx, round(ST_X(Geom)::numeric, 1) AS X, round(ST_Y(Geom)::numeric, 1) AS Y
FROM Reconstructed
WHERE GapId = 3584 AND Model IN ('coordinates', 'crossdomain', 'linear') AND (
  (Task = 'recovery' AND PointIdx = 12) OR (Task = 'prediction' AND PointIdx = 15) OR
  (Task = 'gap' AND PointIdx IN (16, 17)))
ORDER BY Task DESC, PointIdx, Model;

\echo The errors of the position 12 in recovery and of the positions 13 to 15 in prediction (meters)
SELECT Model, Task, PointIdx, round(Err::numeric, 1) AS Err
FROM Errors
WHERE GapId = 3584 AND ((Task = 'recovery' AND PointIdx = 12) OR Task = 'prediction')
ORDER BY Task DESC, PointIdx, Model;

\echo The median recovery error of the masked positions before and after the gap (meters)
SELECT Model, CASE WHEN PointIdx < 16 THEN 'before' ELSE 'after' END AS Side, count(*) AS Positions,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY Err)::numeric) AS MedianErr
FROM Errors
WHERE GapId = 3584 AND Task = 'recovery'
GROUP BY 1, 2
ORDER BY 2 DESC, 1;

\echo The distance of the positions placed inside the gap to the segment from the report 15 to the report 28 (meters)
WITH Segment AS (
  SELECT ST_MakeLine(a.Geom, b.Geom) AS Geom
  FROM TripPoints a JOIN TripPoints b USING (GapId)
  WHERE GapId = 3584 AND a.PointIdx = 15 AND b.PointIdx = 28 )
SELECT r.Model, round(min(ST_Distance(r.Geom, s.Geom))::numeric) AS MinDist,
  round(max(ST_Distance(r.Geom, s.Geom))::numeric) AS MaxDist
FROM Reconstructed r, Segment s
WHERE r.GapId = 3584 AND r.Task = 'gap'
GROUP BY r.Model
ORDER BY r.Model;
