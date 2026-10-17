-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- Vessels from AIS data as temporal rigid geometries
--
-- Prerequisite: ais_input.sql from the volume 1 companion chapter 5 (day 2024-03-01).
--
-- Last run against PostgreSQL 18.1, PostGIS 3.6.1, MobilityDB 1.4.
-------------------------------------------------------------------------------


-- The Reference Geometry of a Vessel

-- Dependency order: the chapter introduces the footprint before the filtering
-- it needs, which reads well but does not run. Built in the other order here.
DROP TABLE IF EXISTS AISInputFilteredPoly CASCADE;
CREATE TABLE AISInputFilteredPoly AS
WITH InvalidGeom(MMSI) AS (
  SELECT MMSI FROM AISInputFiltered
  GROUP BY MMSI
  HAVING COUNT(DISTINCT SizeA) > 1 OR COUNT(DISTINCT SizeB) > 1 OR
    COUNT(DISTINCT SizeC) > 1 OR COUNT(DISTINCT SizeD) > 1 )
SELECT *, ST_X(ST_Transform(Geom, 25832)) AS X,
  ST_Y(ST_Transform(Geom, 25832)) AS Y
FROM AISInputFiltered
WHERE Heading IS NOT NULL AND SizeA IS NOT NULL AND
  SizeB IS NOT NULL AND SizeC IS NOT NULL AND SizeD IS NOT NULL AND
  MMSI NOT IN ( SELECT MMSI FROM InvalidGeom );

DROP TABLE IF EXISTS ShipShape CASCADE;
CREATE TABLE ShipShape(MMSI, Footprint) AS
SELECT MMSI, ST_MakePolygon(ST_MakeLine(ARRAY[
    ST_Point(-SizeB, -SizeC, 25832),
    ST_Point((3 * SizeA - SizeB) / 4, -SizeC, 25832),
    ST_Point(SizeA, (SizeD - SizeC) / 2, 25832),
    ST_Point((3 * SizeA - SizeB) / 4, SizeD, 25832),
    ST_Point(-SizeB, SizeD, 25832),
    ST_Point(-SizeB, -SizeC, 25832)]))
FROM AISInputFilteredPoly
GROUP BY MMSI, SizeA, SizeB, SizeC, SizeD;


-- Preparing Orientation Data



WITH Steps(MMSI, T, Hdg, PrevHdg) AS (
  SELECT MMSI, T, Heading,
    LAG(Heading) OVER (PARTITION BY MMSI ORDER BY T)
  FROM AISInputFilteredPoly )
SELECT MMSI, T, PrevHdg, Hdg
FROM Steps
WHERE PrevHdg IS NOT NULL AND
  LEAST(abs(Hdg - PrevHdg), 360 - abs(Hdg - PrevHdg)) > 180 - 1e-9;


-- From a Record to a Pose

SELECT asText(round(pose(ST_Point(X, Y, 25832),
  CASE WHEN Heading >= 270 THEN pi() / 2 - radians(Heading) + 2 * pi()
       ELSE pi() / 2 - radians(Heading) END), 4))
FROM AISInputFilteredPoly
WHERE MMSI = 219021700 AND T = '2024-03-01 08:00:00';


-- From Poses to a Temporal Rigid Geometry

-- Replaces the Ships table of the volume 1 chapter 5 script, whose Trip is a
-- tgeompoint. Chapter 4 needs the rigid-geometry form; use a dedicated
-- database if you need both.
DROP TABLE IF EXISTS Ships CASCADE;
CREATE TABLE Ships(MMSI, Trip) AS
SELECT a.MMSI, trgeometry(s.Footprint,
  tposeSeq(array_agg(tpose(pose(ST_Point(a.X, a.Y, 25832),
    CASE WHEN a.Heading >= 270
      THEN pi() / 2 - radians(a.Heading) + 2 * pi()
      ELSE pi() / 2 - radians(a.Heading) END), a.T) ORDER BY a.T)))
FROM AISInputFilteredPoly a JOIN ShipShape s USING (MMSI)
GROUP BY a.MMSI, s.Footprint;


-- Questions That Need the Hull

SELECT MMSI, ST_Area(traversedArea(Trip)) AS SweptArea
FROM Ships ORDER BY SweptArea DESC LIMIT 10;

-- KNOWN LIMITATION (MobilityDB 1.4): on a full day this raises
--   Temporal distance: Cycle detected, current features: (4, 2)
-- for a small number of pairs -- 3 of 118 bounding-box neighbours on 2024-03-01.
-- It is a convergence failure in the closest-feature tracking, not a data
-- problem: the hulls involved are valid, convex and non-degenerate. Add
--   AND s1.MMSI <> 205538000
-- to skip the affected vessel on this particular day.
SELECT s1.MMSI, s2.MMSI, s1.Trip |=| s2.Trip AS Dist
FROM Ships s1 JOIN Ships s2 ON s1.MMSI < s2.MMSI
WHERE expandSpace(s1.Trip, 50) && s2.Trip
  AND s1.Trip |=| s2.Trip < 50;

WITH Pier(Geom) AS (
  SELECT geometry 'SRID=25832;Point(651337 6058377)' )
SELECT s.MMSI, s.Trip |=| p.Geom AS HullDist,
  tgeompoint(s.Trip) |=| p.Geom AS PointDist,
  (tgeompoint(s.Trip) |=| p.Geom) - (s.Trip |=| p.Geom) AS Understated
FROM Ships s, Pier p;

WITH Zone(Geom) AS (
  SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832) )
-- KNOWN LIMITATION (MobilityDB 1.4): raises
--   Exact spatial restriction of a temporal rigid geometry with a rotating
--   segment is not implemented
-- The region a rotating body sweeps has curved boundaries, so the exact
-- restriction is genuinely unimplemented rather than merely unwired.
SELECT s.MMSI, duration(getTime(atGeometry(s.Trip, z.Geom))) AS Inside
FROM Ships s, Zone z
WHERE atGeometry(s.Trip, z.Geom) IS NOT NULL;

WITH Quay(Geom) AS (
  SELECT geometry 'SRID=25832;LineString(651337 6058377, 651420 6058455)' )
-- KNOWN LIMITATION (MobilityDB 1.4): a quay is a LineString, and the sequence
-- path of the rigid-geometry distance accepts only Point and Polygon, raising
--   Unsupported geometry type: LineString
-- Until it is widened, buffer the quay into a polygon:
--   ST_Buffer(q.Geom, 0.001)
SELECT s.MMSI, nearestApproachInstant(s.Trip, q.Geom) AS AtInstant,
  s.Trip |=| q.Geom AS Dist
FROM Ships s, Quay q
WHERE s.Trip |=| q.Geom < 20;

SELECT DISTINCT ON (a.MMSI) a.MMSI,
  bodyPointTrajectory(s.Trip, ST_Point(a.SizeA, 0, 25832)) AS BowPath
FROM Ships s JOIN AISInputFilteredPoly a USING (MMSI);

WITH Turn(MMSI, Rot) AS (
  SELECT MMSI, degrees(angularSpeed(tpose(Trip))) FROM Ships )
SELECT MMSI, maxValue(Rot) AS MaxRateDegPerSec
FROM Turn WHERE Rot ?> 5;


-- Heading Is Not Course

WITH Motion(MMSI, D) AS (
  SELECT MMSI, abs(degrees(yaw(Trip)) -
    (90 - degrees(azimuth(tgeompoint(Trip)))))
  FROM Ships )
SELECT MMSI FROM Motion
WHERE atSpanset(D, floatspanset '{(20,340), (380,720)}') IS NOT NULL;
