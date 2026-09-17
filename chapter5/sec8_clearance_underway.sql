-- Section 8: under-keel clearance of the deep-draught vessels while under way
-- outside the port areas. A vessel is under way when the speed over ground it
-- reports exceeds 3 knots; the speed computed from the positions is not used,
-- since the noise of a moored vessel's positions reads as speed.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS PortAreas;
CREATE TABLE PortAreas AS SELECT ST_Union(Geom) AS Geom FROM Port;

DROP TABLE IF EXISTS ReportedSpeed;
CREATE TABLE ReportedSpeed AS
SELECT MMSI, tfloatSeqSetGaps(array_agg(tfloat(SOG, T) ORDER BY T)
  FILTER (WHERE SOG IS NOT NULL), interval '3 minutes') AS SOG
FROM AISNoJump
WHERE MMSI IN (SELECT MMSI FROM Draughts)
GROUP BY MMSI;

DROP TABLE IF EXISTS Underway;
CREATE TABLE Underway AS
SELECT s.MMSI, d.Draught,
  minusGeometry(atTime(s.Trip, whenTrue(r.SOG #> 3)), p.Geom) AS Trip
FROM Ships s JOIN Draughts d USING (MMSI) JOIN ReportedSpeed r USING (MMSI),
  PortAreas p;
DELETE FROM Underway WHERE Trip IS NULL;

DROP TABLE IF EXISTS ClearanceUnderway;
CREATE TABLE ClearanceUnderway AS
SELECT u.MMSI, u.Draught, mergeAgg(rasterValue(u.Trip, b.Rast)) - u.Draught AS Clearance
FROM Underway u, Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(u.Trip))
GROUP BY u.MMSI, u.Draught;

SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  count(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  count(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM ClearanceUnderway;

\echo == the ten smallest clearances, and where the minimum is reached
SELECT c.MMSI, c.Draught, round(minValue(c.Clearance)::numeric, 1) AS MinClearance,
  duration(whenTrue(c.Clearance #< 2)) AS Under2,
  round(ST_X(valueAtTimestamp(s.TripLonLat, startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lon,
  round(ST_Y(valueAtTimestamp(s.TripLonLat, startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lat
FROM ClearanceUnderway c JOIN Ships s USING (MMSI)
ORDER BY minValue(c.Clearance)
LIMIT 10;
