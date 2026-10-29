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

-- Query 1. Trajectories between the ports of Rodby and Puttgarten.
EXPLAIN ANALYZE
WITH Ports(Rodby, Puttgarden) AS (
  SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832),
    ST_MakeEnvelope(644339, 6042108, 644896, 6042487, 25832) )
SELECT s.MMSI, s.Traj, Rodby, Puttgarden
FROM Ports p, Ships s
WHERE eIntersects(s.Trip, p.Rodby) AND eIntersects(s.Trip, p.Puttgarden);

-- Compute and display the vessel activity between the ports of R{\o}dby and Puttgarten, within an alert belt.
EXPLAIN ANALYZE
WITH AlertBelt(Belt) AS (
  SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487, 25832) )
SELECT MMSI, atGeometry(s.Trip, Belt) AS Trip,
  trajectory(atGeometry(s.Trip, Belt)) AS Trajectory
FROM Ships s, AlertBelt b
WHERE eIntersects(s.Trip, Belt);

--Query 3. Compute and display the vessels that during a time interval have been at 300m from 
--each other".
 
WITH Timespan(Period) AS (
SELECT tstzspan '[2024-03-01 11:00:00, 2024-03-01 23:30:00)' ),
TimeShips(MMSI, Trip) AS (
SELECT MMSI, atTime(s.Trip, t.Period)
FROM Ships s TABLESAMPLE SYSTEM(3), Timespan t
WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
TimeClosestShips(MMSI1, MMSI2, ClosestDist, TimeAtClosestDist, Trip1, Trip2) AS (
SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)),
startTimestamp(atMin(s1.Trip <-> s2.Trip)), s1.Trip, s2.Trip
FROM TimeShips s1, TimeShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300) AND
startValue(atMin(s1.Trip <-> s2.Trip)) < 300 )
SELECT t.MMSI1, t.MMSI2, t.ClosestDist, t.TimeAtClosestDist,
valueAtTimestamp(Trip1, TimeAtClosestDist) AS Point1,
valueAtTimestamp(Trip2, TimeAtClosestDist) AS Point2
FROM TimeClosestShips t;  


WITH Hours AS (
    SELECT TIMESTAMP '2024-03-01 13:00:00' AS hour_start
    UNION ALL SELECT TIMESTAMP '2024-03-01 14:00:00'
    UNION ALL SELECT TIMESTAMP '2024-03-01 15:00:00'
    UNION ALL SELECT TIMESTAMP '2024-03-01 16:00:00'
    UNION ALL SELECT TIMESTAMP '2024-03-01 17:00:00'
    UNION ALL SELECT TIMESTAMP '2024-03-01 18:00:00'
    UNION ALL SELECT TIMESTAMP '2024-03-01 19:00:00'
)
SELECT
    h.hour_start,
    COUNT(DISTINCT s.MMSI) AS num_ships
FROM Hours h, Ships s
WHERE atTime(s.Trip, h.hour_start) IS NOT NULL
GROUP BY h.hour_start
ORDER BY h.hour_start;


WITH Timespan(Period) AS (
SELECT tstzspan '[2024-03-01 11:00:00, 2024-03-01 23:30:00)' ),
TimeShips(MMSI, Trip) AS (
SELECT MMSI, atTime(s.Trip, t.Period)
FROM Ships s TABLESAMPLE SYSTEM (10), Timespan t
WHERE atTime(s.Trip, t.Period) IS NOT NULL )
SELECT s1.MMSI, s2.MMSI, s1.Trip, s2.Trip, ST_AsText(trajectory(s1.Trip)::GEOMETRY) as traj1, ST_AsText(trajectory(s2.Trip)::GEOMETRY) as traj2
FROM TimeShips s1, TimeShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300)  ;


WITH Goteborg(GotEnv) AS (
  SELECT ST_MakeEnvelope(666538, 6392057, 679171, 6403745, 25832) )
SELECT s.MMSI, s.Traj , g.GotEnv
FROM Goteborg g, Ships s
WHERE eIntersects(s.Trip, g.GotEnv);



WITH AlertBelt(Belt) AS (
  SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487, 25832)),
BeltShips(MMSI, Trip, Trajectory) AS (
  SELECT MMSI, atGeometry(s.Trip, b.Belt), trajectory(atGeometry(s.Trip, b.Belt))
  FROM Ships s, AlertBelt b
  WHERE eIntersects(s.Trip, b.Belt) )
SELECT s1.MMSI, s2.MMSI, s1.Trajectory, s2.Trajectory,
  shortestLine(s1.Trip, s2.Trip) AS Approach
FROM BeltShips s1, BeltShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 500);




DROP TABLE IF EXISTS malmo;
CREATE TABLE malmo AS (
WITH
malmo_port AS (
SELECT ST_Buffer(
ST_Transform(ST_SetSRID(ST_MakePoint(13.0059, 55.6118), 4326), 25832),
5000
) AS geom
)
SELECT
s.mmsi,
s.trip,
stops(atGeometry(s.trip, m.geom),1000.0, '1 hour'),
trajectory(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')),
StartTimestamp(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')) AS start_time,
EndTimestamp(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')) AS end_time,
traj
FROM
ships s, malmo_port m
WHERE
ST_intersects(trajectory(s.trip), m.geom) AND
stops(atGeometry(s.trip, m.geom), 1000.0, '1 hour') IS NOT NULL AND
ST_geometryType(traj) = 'ST_LineString')

-- Query 8. Trajectories within a radius of 500m around the port of Copenhaghen
 
WITH Port AS (
    SELECT ST_SetSRID(ST_Point(726765.3929300838, 6178705.65508127), 25832)  
	AS port_geom
),
PortBuffer AS (
    SELECT ST_Buffer(port_geom, 500)::geometry AS buf
    FROM Port
)
SELECT 
    s.MMSI AS mmsi,
    ST_AsText(trajectory(s.Trip)),  
    pb.buf 
FROM Ships s, PortBuffer pb
WHERE eIntersects(s.Trip, pb.buf);



WITH
malmo_port AS (
SELECT ST_Buffer(
ST_Transform(ST_SetSRID(ST_MakePoint(13.0059, 55.6118), 4326), 25832),
5000
) AS geom
)
SELECT
s.mmsi,
s.trip,
stops(atGeometry(s.trip, m.geom),1000.0, '1 hour'),
trajectory(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')),
StartTimestamp(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')) AS start_time,
EndTimestamp(stops(atGeometry(s.trip, m.geom),1000.0, '1 hour')) AS end_time,
traj
FROM
ships s, malmo_port m
WHERE
ST_intersects(trajectory(s.trip), m.geom) AND
stops(atGeometry(s.trip, m.geom), 1000.0, '1 hour') IS NOT NULL AND
ST_geometryType(traj) = 'ST_LineString'


WITH Port AS (
    SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom
),
PortBuffer AS (
    SELECT ST_Buffer(port_geom, 2000) AS buf
    FROM Port
)
SELECT s.MMSI AS mmsi,
 stops(atGeometry(s.trip, pb.buf),0.0, interval '20 minutes')),   
 trajectory(atGeometry(s.trip, pb.buf))  AS trip_wkt,
pb.buf AS buffer_wkb
FROM
ships s, PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
stops(atGeometry(s.trip, pb.buf),0.0, interval '20 minutes')) IS NOT NULL AND
ST_GEOMETRYTYPE(trajectory(atGeometry(s.trip, pb.buf)))= 'ST_LINESTRING';
 