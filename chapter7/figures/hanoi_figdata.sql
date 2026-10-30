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

-- Data of the maps of the BerlinMOD-Hanoi section of Chapter 7, in the Hanoi database of DuckDB
-- that load/hanoi_duckdb.sql builds, from the listings of the chapter: the DuckDB twin of
-- hanoi_figdata_pg.sql, with the same columns, orders and simplifications. The geometries are
-- in longitude and latitude for Folium (the clipped trajectories of tripdistricts stay in
-- EPSG:3857). The trajectories drawn at city scale are simplified with a tolerance of 1 m
-- (ST_Simplify), far below a pixel of these maps; the meeting stretches of closetraj are drawn
-- as computed.
SET TimeZone = 'UTC';
SET threads = 1;
SET memory_limit = '7000MB';
CREATE TEMP MACRO lonlat(g) AS ST_AsText(ST_Transform(g, 'EPSG:3857', 'EPSG:4326', true));
COPY (
SELECT tripid, vehicleid, lonlat(ST_Simplify(trajectory, 1.0)) AS traj
FROM trips
ORDER BY tripid
) TO 'data/hanoi/trips.csv' (HEADER);
COPY (
SELECT municipalityid, municipalityname, lonlat(municipalitygeo) AS geo,
  ST_AsText(municipalitygeo) AS geo3857
FROM municipalities
ORDER BY municipalityid
) TO 'data/hanoi/municipalities.csv' (HEADER);
COPY (
WITH tripInt AS (
  SELECT vehicleid, tripid,
    COUNT(DISTINCT m.municipalityid) AS intersectCount
  FROM trips t, municipalities m
  WHERE eintersects(trip, municipalitygeo)
  GROUP BY vehicleid, tripid )
SELECT t1.*, lonlat(ST_Simplify(t.trajectory, 1.0)) AS trajectory
FROM trips t JOIN tripInt t1 ON (t.tripId = t1.tripId AND t.vehicleid = t1.vehicleid)
ORDER BY intersectCount DESC, t1.tripid
LIMIT 5
) TO 'data/hanoi/maxtripmuni.csv' (HEADER);
COPY (
SELECT municipalityid, municipalityname, COUNT(*) AS intersectCount
FROM trips t, municipalities m
WHERE eintersects(t.trip, m.municipalitygeo)
GROUP BY municipalityid, municipalityname
ORDER BY 3 DESC, municipalityid
) TO 'data/hanoi/districtcount.csv' (HEADER);
COPY (
WITH Top6 AS (
  SELECT m.municipalityid, COUNT(*) AS c
  FROM trips t, municipalities m
  WHERE eintersects(t.trip, m.municipalitygeo)
  GROUP BY m.municipalityid
  ORDER BY c DESC, m.municipalityid
  LIMIT 6 )
SELECT m.municipalityname, t.tripid,
  ST_AsText(ST_Simplify(trajectory(atGeometry(t.trip, m.municipalitygeo)), 1.0)) AS trajClip
FROM trips t, municipalities m, Top6 x
WHERE m.municipalityid = x.municipalityid AND eintersects(t.trip, m.municipalitygeo)
ORDER BY m.municipalityname, t.tripid
) TO 'data/hanoi/districttrips.csv' (HEADER);
COPY (
SELECT m.MunicipalityName AS municipalityname,
  round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 3) AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo)
GROUP BY m.MunicipalityName
ORDER BY 1
) TO 'data/hanoi/totaldist.csv' (HEADER);
COPY (
SELECT DISTINCT t1.VehicleId AS VehicleId1, t1.TripId AS TripId1,
  lonlat(ST_Simplify(t1.Trajectory, 1.0)) AS Traj1, t2.VehicleId AS VehicleId2,
  t2.TripId AS TripId2, lonlat(ST_Simplify(t2.Trajectory, 1.0)) AS Traj2
FROM (SELECT * FROM trips ORDER BY TripId LIMIT 1000) t1,
  (SELECT * FROM trips ORDER BY TripId LIMIT 1000) t2
WHERE t1.VehicleId < t2.VehicleId AND eDwithin(t1.Trip, t2.Trip, 10.0)
ORDER BY 1, 4, 2, 5
) TO 'data/hanoi/closepairs.csv' (HEADER);
COPY (
WITH Temp AS (
  SELECT l1.Licence AS Licence1,
    t2.VehicleId AS Car2Id, whenTrue(tDwithin(t1.Trip, t2.Trip, 3.0)) AS Periods,
    atTime(t1.trip, whenTrue(tDwithin(t1.Trip, t2.Trip, 3.0))) AS tt1,
    atTime(t2.trip, whenTrue(tDwithin(t1.Trip, t2.Trip, 3.0))) AS tt2
  FROM Trips t1, Licences1 l1, Trips t2, Vehicles v
  WHERE t1.VehicleId = l1.VehicleId AND
    t2.VehicleId = v.VehicleId AND
    t1.VehicleId <> t2.VehicleId AND
    t2.Trip && expandSpace(t1.trip::STBOX, 3.0) )
SELECT Licence1 AS licence1, Car2Id AS car2id, lonlat(trajectory(tt1)) AS geom1,
  lonlat(trajectory(tt2)) AS geom2, Periods::VARCHAR AS periods
FROM Temp
WHERE Periods IS NOT NULL
ORDER BY 1, 2, 5
) TO 'data/hanoi/closetraj.csv' (HEADER);
COPY (
SELECT DISTINCT t.TripId AS tripid, v.Licence AS licence, p.PointId AS pointid,
  lonlat(p.Geom) AS point, startTimestamp(atValue(t.Trip, p.Geom)) AS Instant,
  lonlat(ST_Simplify(t.trajectory, 1.0)) AS trajectory
FROM Trips t, Vehicles v, Points p
WHERE t.VehicleId = v.VehicleId AND v.VehicleType = 'passenger' AND
  eIntersects(t.Trip, ST_Buffer(p.Geom, 10))
) TO 'data/hanoi/tripsinstants.csv' (HEADER);
