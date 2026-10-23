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

-- Data of the maps of the MobilityDuck AIS section (rodbyputt, belt, pointsclose300_a/b,
-- close300_a/b, copenh, copenhstop): the results of the queries printed in the chapter, with
-- their geometries transformed from EPSG:25832 to longitude and latitude for Folium.
SET TimeZone = 'UTC';
SET threads = 1;
SET memory_limit = '7000MB';
CREATE TEMP MACRO lonlat(g) AS ST_AsText(ST_Transform(g, 'EPSG:25832', 'EPSG:4326', true));
COPY (
WITH Ports(Rodby, Puttgarden) AS
  (SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548),
    ST_MakeEnvelope(644339, 6042108, 644896, 6042487))
SELECT s.MMSI, lonlat(trajectory(trip)) AS Trajectory,
  lonlat(Rodby) AS Rodby, lonlat(Puttgarden) AS Puttgarden
FROM Ports p, Ships s
WHERE eintersects(trip, p.Rodby) AND eintersects(trip, p.Puttgarden)
) TO 'data/ais/rodbyputt.csv' (HEADER);
COPY (
WITH AlertBelt(Belt) AS (
SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487))
SELECT MMSI, lonlat(trajectory(atGeometry(s.Trip,  b.Belt))) as traj,
  lonlat(b.Belt) AS belt
FROM ships s, AlertBelt b
WHERE eintersects(s.Trip, b.Belt)
) TO 'data/ais/belt.csv' (HEADER);
COPY (
WITH Timespan(Period) AS (
  SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
  SELECT MMSI, atTime(s.Trip, t.Period)
  FROM Ships s TABLESAMPLE RESERVOIR (300 ROWS) REPEATABLE (1), Timespan t
  WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
TimeClosestShips(MMSI1, MMSI2, ClosestDist, TimeAtClosestDist, Trip1, Trip2) AS (
  SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)),
    startTimestamp(atMin(s1.Trip <-> s2.Trip)), s1.Trip, s2.Trip
  FROM TimeShips s1, TimeShips s2
  WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300) AND
    startValue(atMin(s1.Trip <-> s2.Trip)) < 300 )
SELECT t.MMSI1, t.MMSI2, t.ClosestDist, t.TimeAtClosestDist,
  lonlat(valueAtTimestamp(Trip1, TimeAtClosestDist)) AS Point1,
  lonlat(valueAtTimestamp(Trip2, TimeAtClosestDist)) AS Point2
FROM TimeClosestShips t
) TO 'data/ais/pointsclose300.csv' (HEADER);
COPY (
WITH Timespan(Period) AS (
  SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
  SELECT MMSI, atTime(s.Trip, t.Period)
  FROM Ships s TABLESAMPLE RESERVOIR (300 ROWS) REPEATABLE (1), Timespan t
  WHERE atTime(s.Trip, t.Period) IS NOT NULL )
SELECT s1.MMSI AS MMSI, s2.MMSI AS MMSI_1,
  lonlat(trajectory(s1.Trip)) as traj1,
  lonlat(trajectory(s2.Trip)) as traj2
FROM TimeShips s1, TimeShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300)
) TO 'data/ais/close300.csv' (HEADER);
COPY (
WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 500) AS buf
  FROM Port )
SELECT s.MMSI AS mmsi, lonlat(trajectory(s.Trip)) AS trip_wkt,
    lonlat(ST_Centroid(pb.buf)) AS buffer_center
FROM Ships s, PortBuffer pb
WHERE eIntersects(s.Trip, pb.buf)
) TO 'data/ais/copenh.csv' (HEADER);
COPY (
WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 1000) AS buf
  FROM Port )
SELECT s.MMSI AS mmsi,
  lonlat(trajectory(atGeometry(s.trip, pb.buf))) AS trip_wkt,
  lonlat(ST_Centroid(pb.buf)) AS buffer_center
FROM ships s, PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
  astext(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes'))
    IS NOT NULL
) TO 'data/ais/copenhstop.csv' (HEADER);
