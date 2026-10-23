/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- Case study, Under-Keel Clearance: the clearance of the vessels with a draught of
-- at least 10 m, under way outside the ports by the speed they report, and the
-- shallowest water within 100 m of the vessel 273277840 from the table
-- BathymetryMin100 of map_algebra.sql. The reported speed is the column SOG of
-- Ships, and the port areas are the table PortAreas of chapter3/ships_noise.sql.
-- Each listing of the chapter is preceded by its printed answer; the other
-- queries give the numbers stated in the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Query: vessels with a draught of at least 10 m and less than 5 m, less than 2 m, and less than 0 m of clearance
-- 103 | 31 | 7 | 6
DROP TABLE IF EXISTS Draughts, Clearance;
CREATE TABLE Draughts AS
SELECT MMSI, MAX(Draught) AS Draught
FROM AISClean
GROUP BY MMSI
HAVING MAX(Draught) >= 10;
CREATE TABLE Clearance AS
SELECT s.MMSI, d.Draught,
  mergeAgg(rasterValue(s.Trip, b.Rast)) - d.Draught AS Clearance
FROM Ships s JOIN Draughts d USING (MMSI), Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(s.Trip))
GROUP BY s.MMSI, d.Draught;
SELECT COUNT(*) AS Vessels,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM Clearance;
\echo == vessels that reported a draught of at least 10 m (162)
SELECT COUNT(*) AS Vessels FROM Draughts;

\echo == the six negative clearances: in a port area at the minimum, and the speed from the positions (m/s)
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
   538010052 |      10 |      2.0 |                 | 10.362 | 56.242
   636024484 |      10 |      2.2 |                 | 10.238 | 56.153
   636023680 |      15 |      2.3 |                 | 12.668 | 54.748
   636018579 |      15 |      2.3 |                 | 12.362 | 54.632
   ... */
DROP TABLE IF EXISTS Underway, ClearanceUnderway;
CREATE TABLE Underway AS
SELECT s.MMSI, d.Draught,
  minusGeometry(atTime(s.Trip, whenTrue(s.SOG #> 3)), p.Geom) AS Trip
FROM Ships s JOIN Draughts d USING (MMSI), PortAreas p;
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
SELECT COUNT(*) AS Vessels,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 5) AS Under5,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 2) AS Under2,
  COUNT(*) FILTER (WHERE minValue(Clearance) < 0) AS Negative
FROM ClearanceUnderway;
\echo == the vessel approaching Aarhus while its clearance is less than 2 m: km sailed and mean reported speed (7.2 | 4.8)
SELECT round((length(atTime(u.Trip, whenTrue(c.Clearance #< 2))) / 1000)::numeric, 1) AS Km,
  round(twAvg(atTime(s.SOG, whenTrue(c.Clearance #< 2)))::numeric, 1) AS AvgSOG
FROM ClearanceUnderway c JOIN Underway u USING (MMSI) JOIN Ships s USING (MMSI)
WHERE c.MMSI = 636024511;
\echo == under way by the speed computed from the positions: the vessels with a negative clearance, the speed from the positions and the reported speed at the minimum (knots), and where (219018501 | 11.6 | -1.1 | 4.2 | 2.0 | 10.245 | 56.159)
WITH u AS (
  SELECT s.MMSI, d.Draught,
    minusGeometry(atTime(s.Trip, whenTrue(speed(s.Trip) #> 3 * 1852 / 3600.0)), p.Geom) AS Trip
  FROM Ships s JOIN Draughts d USING (MMSI), PortAreas p ),
c AS (
  SELECT u.MMSI, u.Draught, mergeAgg(rasterValue(u.Trip, b.Rast)) - u.Draught AS Clearance
  FROM u, Bathymetry b
  WHERE u.Trip IS NOT NULL AND ST_Intersects(b.Rast, trajectory(u.Trip))
  GROUP BY u.MMSI, u.Draught )
SELECT c.MMSI, c.Draught, round(minValue(c.Clearance)::numeric, 1) AS MinClear,
  round((valueAtTimestamp(speed(s.Trip), startTimestamp(atMin(c.Clearance))) * 3600 / 1852)::numeric, 1)
    AS SpeedPos,
  round(valueAtTimestamp(s.SOG, startTimestamp(atMin(c.Clearance)))::numeric, 1) AS SOG,
  round(ST_X(valueAtTimestamp(s.TripLonLat, startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lon,
  round(ST_Y(valueAtTimestamp(s.TripLonLat, startTimestamp(atMin(c.Clearance))))::numeric, 3) AS Lat
FROM c JOIN Ships s USING (MMSI)
WHERE minValue(c.Clearance) < 0
ORDER BY 3;

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
