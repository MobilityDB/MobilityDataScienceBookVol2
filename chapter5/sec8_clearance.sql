-- Section 8: under-keel clearance of every vessel of the day with a draught of
-- at least 10 m, from the depth under its trip minus its reported draught.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS Draughts;
CREATE TABLE Draughts AS
SELECT MMSI, max(Draught) AS Draught
FROM AISClean
GROUP BY MMSI
HAVING max(Draught) >= 10;

DROP TABLE IF EXISTS Clearance;
CREATE TABLE Clearance AS
SELECT s.MMSI, d.Draught, mergeAgg(rasterValue(s.Trip, b.Rast)) - d.Draught AS Clearance
FROM Ships s JOIN Draughts d USING (MMSI), Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(s.Trip))
GROUP BY s.MMSI, d.Draught;

\echo == vessels, and those with less than 2 m and 5 m of clearance at some time
SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  count(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  count(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM Clearance;

\echo == the ten smallest clearances
SELECT MMSI, Draught, round(minValue(Clearance)::numeric, 1) AS MinClearance,
  duration(whenTrue(Clearance #< 2)) AS Under2
FROM Clearance
ORDER BY minValue(Clearance)
LIMIT 10;
