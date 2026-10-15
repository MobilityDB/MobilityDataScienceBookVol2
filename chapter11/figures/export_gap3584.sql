-- The data of the figure of the gap 3584 of the use case of chapter 11, read by fig_gap3584.py:
-- the one-minute positions of its window (tp.csv), the AIS reports of the vessel from 15 minutes
-- before the gap to 15 minutes after it (obs.csv), the reconstructions of the models crossdomain and
-- coordinates and of the baseline linear (rec.csv), and the positions fixed for each task
-- (masks.csv). The times are written in the time zone of Denmark, in which the figure gives them.
--
--   psql -d ais -f export_gap3584.sql

\set ON_ERROR_STOP on
SET TimeZone = 'Europe/Brussels';

\copy (SELECT p.PointIdx, p.T, p.InGap, ST_X(p.Geom) AS x, ST_Y(p.Geom) AS y, p.T IN (g.TStart, g.TEnd) AS bound FROM TripPoints p JOIN Gaps g USING (GapId) WHERE GapId = 3584 ORDER BY p.PointIdx) TO 'tp.csv' CSV HEADER
\copy (SELECT c.T AT TIME ZONE 'UTC' AS t, ST_X(c.Geom) AS x, ST_Y(c.Geom) AS y, c.SOG AS sog, c.COG AS cog FROM AISClean c JOIN Gaps g USING (MMSI) WHERE g.GapId = 3584 AND (c.T AT TIME ZONE 'UTC') BETWEEN g.TStart - interval '15 minutes' AND g.TEnd + interval '15 minutes' ORDER BY c.T) TO 'obs.csv' CSV HEADER
\copy (SELECT Model, Task, PointIdx, ST_X(Geom) AS x, ST_Y(Geom) AS y FROM Reconstructed WHERE GapId = 3584 AND Model IN ('coordinates', 'crossdomain', 'linear') ORDER BY Model, Task, PointIdx) TO 'rec.csv' CSV HEADER
\copy (SELECT Task, PointIdx FROM EvalMasks WHERE GapId = 3584 ORDER BY Task, PointIdx) TO 'masks.csv' CSV HEADER
