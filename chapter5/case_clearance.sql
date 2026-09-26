-- Case study, Under-Keel Clearance: the clearance of the vessels with a draught of
-- at least 10 m, under way outside the ports by the speed they report, and the
-- shallowest water within 100 m of the vessel 273277840 from the table
-- BathymetryMin100 of map_algebra.sql. Each listing of the chapter is preceded
-- by its printed answer; the other queries give the numbers stated in the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Query: vessels with a draught of at least 10 m and less than 5 m, less than 2 m, and less than 0 m of clearance
-- 104 | 32 | 8 | 7
DROP TABLE IF EXISTS Draughts, Clearance;
CREATE TABLE Draughts AS
SELECT MMSI, max(Draught) AS Draught
FROM AISClean
GROUP BY MMSI
HAVING max(Draught) >= 10;
CREATE TABLE Clearance AS
SELECT s.MMSI, d.Draught,
  mergeAgg(rasterValue(s.Trip, b.Rast)) - d.Draught AS Clearance
FROM Ships s JOIN Draughts d USING (MMSI), Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(s.Trip))
GROUP BY s.MMSI, d.Draught;
SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  count(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  count(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM Clearance;
\echo == vessels that reported a draught of at least 10 m (163)
SELECT count(*) AS Vessels FROM Draughts;

\echo == the seven negative clearances: in a port area at the minimum, and the speed from the positions (m/s)
SELECT c.MMSI, round(minValue(c.Clearance)::numeric, 1) AS MinClear,
  EXISTS (SELECT 1 FROM Port p WHERE ST_Intersects(p.Geom,
    valueAtTimestamp(s.Trip, startTimestamp(atMin(c.Clearance))))) AS InPort,
  round(valueAtTimestamp(speed(s.Trip), startTimestamp(atMin(c.Clearance)))::numeric, 1)
    AS Speed
FROM Clearance c JOIN Ships s USING (MMSI)
WHERE minValue(c.Clearance) < 0
ORDER BY 2;

\echo == Query: vessels under way outside the ports with the smallest clearance
/* MMSI      | Draught | MinClear | Under2          | Lon    | Lat
   636024511 |    13.2 |      0.7 | 00:48:00.708846 | 10.249 | 56.159
   636023850 |    10.5 |      1.9 | 00:00:26.658441 | 10.881 | 54.766
   538010052 |    10.0 |      2.0 |                 | 10.362 | 56.242
   636024484 |    10.0 |      2.2 |                 | 10.238 | 56.153
   636023680 |    15.0 |      2.3 |                 | 12.668 | 54.748
   636018579 |    15.0 |      2.3 |                 | 12.362 | 54.632
   ... */
DROP TABLE IF EXISTS PortAreas, ReportedSpeed, Underway, ClearanceUnderway;
CREATE TABLE PortAreas AS
SELECT ST_Union(Geom) AS Geom FROM Port;
CREATE TABLE ReportedSpeed AS
SELECT MMSI, tfloatSeqSetGaps(array_agg(tfloat(SOG, T) ORDER BY T)
  FILTER (WHERE SOG IS NOT NULL), interval '3 minutes') AS SOG
FROM AISNoJump
WHERE MMSI IN (SELECT MMSI FROM Draughts)
GROUP BY MMSI;
CREATE TABLE Underway AS
SELECT s.MMSI, d.Draught,
  minusGeometry(atTime(s.Trip, whenTrue(r.SOG #> 3)), p.Geom) AS Trip
FROM Ships s JOIN Draughts d USING (MMSI) JOIN ReportedSpeed r USING (MMSI),
  PortAreas p;
CREATE TABLE ClearanceUnderway AS
SELECT u.MMSI, u.Draught,
  mergeAgg(rasterValue(u.Trip, b.Rast)) - u.Draught AS Clearance
FROM Underway u, Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(u.Trip))
GROUP BY u.MMSI, u.Draught;
SELECT c.MMSI, c.Draught, round(minValue(c.Clearance)::numeric, 1) AS MinClear,
  duration(whenTrue(c.Clearance #< 2)) AS Under2,
  round(ST_X(valueAtTimestamp(s.TripLonLat,
    startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lon,
  round(ST_Y(valueAtTimestamp(s.TripLonLat,
    startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lat
FROM ClearanceUnderway c JOIN Ships s USING (MMSI)
ORDER BY minValue(c.Clearance)
LIMIT 10;
\echo == vessels under way over the bathymetry, and with less than 5, 2, and 0 m of clearance (99 | 29 | 2 | 0)
SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  count(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  count(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM ClearanceUnderway;
\echo == the vessel approaching Aarhus while its clearance is less than 2 m: km sailed and mean reported speed (7.2 | 4.8)
SELECT round((length(atTime(u.Trip, whenTrue(c.Clearance #< 2))) / 1000)::numeric, 1) AS Km,
  round(twAvg(atTime(r.SOG, whenTrue(c.Clearance #< 2)))::numeric, 1) AS AvgSOG
FROM ClearanceUnderway c JOIN Underway u USING (MMSI) JOIN ReportedSpeed r USING (MMSI)
WHERE c.MMSI = 636024511;
\echo == the vessel moored at Grenaa: highest reported speed, and clearance when under way by the speed from the positions (0.0 | -7.2)
SELECT round(maxValue(SOG)::numeric, 1) AS MaxSOG FROM ReportedSpeed WHERE MMSI = 538010662;
WITH u AS (
  SELECT s.MMSI, d.Draught,
    minusGeometry(atTime(s.Trip, whenTrue(speed(s.Trip) #> 3 * 1852 / 3600.0)), p.Geom) AS Trip
  FROM Ships s JOIN Draughts d USING (MMSI), PortAreas p
  WHERE s.MMSI = 538010662 )
SELECT u.MMSI,
  round((minValue(mergeAgg(rasterValue(u.Trip, b.Rast))) - u.Draught)::numeric, 1) AS MinClear
FROM u, Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(u.Trip))
GROUP BY u.MMSI, u.Draught;

\echo == Query: when was there water less than 20 m deep within 100 m of the vessel
-- 12 | 00:25:58.197711
WITH VesselDepth AS (
  SELECT mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, BathymetryMin100 b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) )
SELECT numSpans(whenTrue(Depth #< 20)) AS Periods,
  duration(whenTrue(Depth #< 20)) AS Total
FROM VesselDepth;
\echo == the periods, to compare with those under the reported positions
WITH VesselDepth AS (
  SELECT mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, BathymetryMin100 b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) )
SELECT unnest(spans(whenTrue(Depth #< 20))) AS Period
FROM VesselDepth;
