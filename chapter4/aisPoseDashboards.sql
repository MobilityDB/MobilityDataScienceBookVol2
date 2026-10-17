-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- Vessel-traffic analytics, as a maritime authority would ask them
--
-- Run ais_poses.sql first.
--
-- Last run against PostgreSQL 18.1, PostGIS 3.6.1, MobilityDB 1.4.
-------------------------------------------------------------------------------


-- Vessel Separation

-- KNOWN LIMITATION (MobilityDB 1.4): the temporal distance between two rigid
-- geometries raises
--   Temporal distance: Cycle detected, current features: (4, 2)
-- for a small number of pairs -- 3 of 118 bounding-box neighbours on 2024-03-01,
-- all involving MMSI 205538000. It is a convergence failure in the closest-feature
-- tracking, not a data problem: the hulls concerned are valid, convex and
-- non-degenerate. Add
--   AND s1.MMSI <> 205538000
-- to skip the affected vessel on this particular day.
SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)) AS Dist
FROM Ships s1, Ships s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300);

-- KNOWN LIMITATION (MobilityDB 1.4): the temporal distance between two rigid
-- geometries raises
--   Temporal distance: Cycle detected, current features: (4, 2)
-- for a small number of pairs -- 3 of 118 bounding-box neighbours on 2024-03-01,
-- all involving MMSI 205538000. It is a convergence failure in the closest-feature
-- tracking, not a data problem: the hulls concerned are valid, convex and
-- non-degenerate. Add
--   AND s1.MMSI <> 205538000
-- to skip the affected vessel on this particular day.
SELECT s1.MMSI, s2.MMSI,
  startValue(atMin(s1.Trip <-> s2.Trip)) AS HullDist,
  startValue(atMin(tgeompoint(s1.Trip) <-> tgeompoint(s2.Trip))) AS PointDist
FROM Ships s1, Ships s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300);


-- The Alert Belt

WITH AlertBelt(Belt) AS (
  SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487, 25832) )
-- KNOWN LIMITATION (MobilityDB 1.4): atGeometry on a rigid geometry raises
--   Exact spatial restriction of a temporal rigid geometry with a rotating
--   segment is not implemented
-- The region a rotating body sweeps has curved boundaries, so the exact
-- restriction is genuinely unimplemented rather than merely unwired.
SELECT MMSI, atGeometry(s.Trip, Belt) AS Trip
FROM Ships s, AlertBelt b
WHERE eIntersects(s.Trip, Belt);


-- Port Occupation

WITH Port(Geom) AS (
  SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832) ),
-- KNOWN LIMITATION (MobilityDB 1.4): atGeometry on a rigid geometry raises
--   Exact spatial restriction of a temporal rigid geometry with a rotating
--   segment is not implemented
-- The region a rotating body sweeps has curved boundaries, so the exact
-- restriction is genuinely unimplemented rather than merely unwired.
Inside(MMSI, Trip) AS (
  SELECT s.MMSI, atGeometry(s.Trip, p.Geom)
  FROM Ships s, Port p
  WHERE atGeometry(s.Trip, p.Geom) IS NOT NULL ),
Used(Geom) AS (
  SELECT ST_Union(traversedArea(Trip)) FROM Inside )
SELECT ST_Area(u.Geom) AS WaterUsed,
  ST_Area(ST_Intersection(u.Geom, p.Geom)) AS WithinBasin
FROM Used u, Port p;


-- Traffic Density as Occupied Water

WITH Grid(CellId, Cell) AS (
  SELECT (g).i * 1000 + (g).j, (g).geom
  FROM ST_SquareGrid(1000,
    ST_MakeEnvelope(600000, 6000000, 700000, 6100000, 25832)) AS g ),
Swept(MMSI, Area) AS (
  SELECT MMSI, traversedArea(Trip) FROM Ships )
SELECT c.CellId, SUM(ST_Area(ST_Intersection(s.Area, c.Cell))) AS Occupied
FROM Grid c JOIN Swept s ON s.Area && c.Cell
GROUP BY c.CellId;


-- Occupancy over Time

WITH AlertBelt(Belt) AS (
  SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487, 25832) )
SELECT tCount(atGeometry(s.Trip, b.Belt)) AS Present
FROM Ships s, AlertBelt b;

SELECT maxValue(tCount(atGeometry(Trip, Port.Geom))) AS PeakVessels,
  twAvg(tCount(atGeometry(Trip, Port.Geom))) AS MeanVessels
FROM Ships, Port;


-- Operational Questions

SELECT s1.MMSI, s2.MMSI, s1.Trip |=| s2.Trip AS Cpa,
  nearestApproachInstant(s1.Trip, s2.Trip) AS Tcpa
FROM Ships s1, Ships s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 500);

SELECT s.MMSI, duration(getTime(atGeometry(s.Trip, a.Geom))) AS TimeInside
FROM Ships s, ProtectedArea a
WHERE eIntersects(s.Trip, a.Geom)
ORDER BY TimeInside DESC;

WITH Inside(MMSI, Trip) AS (
  SELECT s.MMSI, atGeometry(s.Trip, r.Geom)
  FROM Ships s, RestrictedArea r
  WHERE atGeometry(s.Trip, r.Geom) IS NOT NULL )
SELECT MMSI, twAvg(speed(Trip)) AS MeanSpeed,
  maxValue(speed(Trip)) AS MaxSpeed
FROM Inside;

SELECT MMSI, ST_AsText(valueAtTimestamp(Trip,
  timestamptz '2023-03-01 14:32:17')) AS Hull,
  degrees(valueAtTimestamp(yaw(Trip),
  timestamptz '2023-03-01 14:32:17')) AS Heading
FROM Ships
WHERE Trip |=| geometry 'SRID=25832;Point(651337 6058377)' < 3704;

SELECT MMSI, maxValue(degrees(angularSpeed(tpose(Trip)))) AS PeakRot
FROM Ships
WHERE degrees(angularSpeed(tpose(Trip))) ?> 3;

SELECT MMSI, numSequences(Trip) - 1 AS Gaps,
  duration(getTime(Trip)) AS Observed,
  duration(timeSpan(Trip)) AS Elapsed
FROM Ships
WHERE numSequences(Trip) > 1
ORDER BY duration(timeSpan(Trip)) - duration(getTime(Trip)) DESC;
