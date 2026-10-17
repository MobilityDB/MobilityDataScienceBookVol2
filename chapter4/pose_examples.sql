-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- The worked examples of the type sections
--
-- Needs no dataset. The comment under each statement is the answer it produced.
--
-- Last run against PostgreSQL 18.1, PostGIS 3.6.1, MobilityDB 1.4.
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Composition of Poses
-------------------------------------------------------------------------------

SELECT asText(pose(posechain(ARRAY[
  pose 'Pose(Point(100 50), 0)',
  pose 'Pose(Point(2 0), 1.5707963267948966)'])));
-- Pose(POINT(102 50),1.570796326794897)

SELECT ST_AsText(applyPose(geometry 'Point(102 52)',
  poseInverse(pose 'Pose(Point(100 50), 0)')));
-- POINT(2 2)

SELECT asText(pose 'Pose(Point(1 1),0.5)');
-- Pose(POINT(1 1),0.5)
SELECT asText(pose(ST_Point(1,1), 0.5));
-- Pose(POINT(1 1),0.5)
SELECT asText(pose 'Pose(Point(0 0 0), 1, 0, 0, 0)');
-- Pose(POINT Z (0 0 0),1,0,0,0)

SELECT ST_AsText(point(pose 'Pose(Point(1 1),0.5)'));
-- POINT(1 1)
SELECT yaw(pose 'Pose(Point(1 1),0.5)');
-- 0.5
SELECT yaw(pose 'Pose(Point(0 0 0), 1, 0, 0, 0)');
-- 0


-------------------------------------------------------------------------------
-- Applying a Pose
-------------------------------------------------------------------------------

SELECT ST_AsText(applyPose(ST_Point(1,2), pose 'Pose(Point(0 0), 0)'));
-- POINT(1 2)
SELECT ST_AsText(applyPose(ST_Point(1,0),
  pose 'Pose(Point(10 20), 1.5707963267948966)'));
-- POINT(10 21)
SELECT ST_AsText(applyPose(ST_MakePoint(1,0,0),
  pose 'Pose(Point(10 20 30), 1, 0, 0, 0)'));
-- POINT Z (11 20 30)

SELECT asText(tpose 'Pose(Point(1 1), 0.5)@2000-01-01');
-- Pose(POINT(1 1),0.5)@2000-01-01
SELECT asText(tpose '{Pose(Point(1 1), 0.3)@2000-01-01,
  Pose(Point(1 1), 0.5)@2000-01-02}');
-- {Pose(POINT(1 1),0.3)@2000-01-01, Pose(POINT(1 1),0.5)@2000-01-02}
SELECT asText(tpose '[Pose(Point(1 1), 0.2)@2000-01-01,
  Pose(Point(1 1), 0.4)@2000-01-02, Pose(Point(1 1), 0.5)@2000-01-03]');
/* [Pose(POINT(1 1),0.2)@2000-01-01, Pose(POINT(1 1),0.4)@2000-01-02,
   Pose(POINT(1 1),0.5)@2000-01-03] */


-------------------------------------------------------------------------------
-- Constructing and Converting Subtypes
-------------------------------------------------------------------------------

SELECT asText(tposeSeq(ARRAY[tpose 'Pose(Point(1 1),0)@2001-01-01',
  'Pose(Point(2 2),1)@2001-01-02'], 'discrete'));
-- {Pose(POINT(1 1),0)@2001-01-01, Pose(POINT(2 2),1)@2001-01-02}
SELECT asText(tposeSeq(ARRAY[tpose 'Pose(Point(1 1),0)@2001-01-01',
  'Pose(Point(1 1),1)@2001-01-02'], 'linear', true, false));
-- [Pose(POINT(1 1),0)@2001-01-01, Pose(POINT(1 1),1)@2001-01-02)

SELECT asText(tposeSeqSet(ARRAY[tpose
  '[Pose(Point(1 1),0)@2001-01-01, Pose(Point(1 1),1)@2001-01-02]',
  '[Pose(Point(2 2),0)@2001-01-03, Pose(Point(2 2),1)@2001-01-04]']));
/* {[Pose(POINT(1 1),0)@2001-01-01, Pose(POINT(1 1),1)@2001-01-02],
   [Pose(POINT(2 2),0)@2001-01-03, Pose(POINT(2 2),1)@2001-01-04]} */
SELECT asText(tposeSeqSet(tpose '{Pose(Point(1 1),0.3)@2001-01-01,
  Pose(Point(1 1),0.5)@2001-01-02}'));
-- {[Pose(POINT(1 1),0.3)@2001-01-01], [Pose(POINT(1 1),0.5)@2001-01-02]}

SELECT timeSpan(tpose '{[Pose(Point(1 1),0.2)@2001-01-01,
  Pose(Point(1 1),0.5)@2001-01-03], [Pose(Point(2 2),0.6)@2001-01-05]}');
-- [2001-01-01, 2001-01-05]
SELECT getTime(tpose '{[Pose(Point(1 1),0.2)@2001-01-01,
  Pose(Point(1 1),0.5)@2001-01-03], [Pose(Point(2 2),0.6)@2001-01-05]}');
-- {[2001-01-01, 2001-01-03], [2001-01-05, 2001-01-05]}

SELECT asText(trgeometry 'Polygon((0 0,1 0,1 1,0 1,0 0));
  [Pose(Point(0 0),0)@2026-01-01, Pose(Point(2 0),0)@2026-01-02]');
/* POLYGON((0 0,1 0,1 1,0 1,0 0));[Pose(POINT(0 0),0)@2026-01-01,
   Pose(POINT(2 0),0)@2026-01-02] */
SELECT ST_AsText(valueAtTimestamp(trgeometry 'Polygon((1 1,2 2,3 1,1 1));
  Pose(Point(1 1), 0.5)@2000-01-01', '2000-01-01'));
/* POLYGON((1.39815702328617 2.357008100494576,
   1.79631404657234 3.714016200989152,
   3.153322147066915 3.315859177702982,
   1.39815702328617 2.357008100494576)) */


-------------------------------------------------------------------------------
-- Constructors and Accessors
-------------------------------------------------------------------------------

SELECT asText(trgeometry('Polygon((1 1,2 2,3 1,1 1))',
  tpose(pose 'Pose(Point(1 1),0)', timestamptz '2001-01-01')));
-- POLYGON((1 1,2 2,3 1,1 1));Pose(POINT(1 1),0)@2001-01-01
-- The chapter uses the span form of the constructor. MobilityDB 1.4 defines
-- trgeometry(geometry, pose, timestamptz) but not yet the tstzset, tstzspan and
-- tstzspanset forms that tpose already has, so compose the two constructors
-- that do exist; the result is identical.
SELECT asText(trgeometry('Polygon((1 1,2 2,3 1,1 1))',
  tpose(pose 'Pose(Point(1 1),0.5)', tstzspan '[2001-01-01, 2001-01-02]')));
/* POLYGON((1 1,2 2,3 1,1 1));[Pose(POINT(1 1),0.5)@2001-01-01,
   Pose(POINT(1 1),0.5)@2001-01-02] */

SELECT ST_AsText(trgeometry 'Polygon((1 1,2 2,3 1,1 1));
  Pose(Point(1 1),0.5)@2001-01-01'::geometry);
-- POLYGON((1 1,2 2,3 1,1 1))
SELECT asText(tpose(trgeometry 'Polygon((1 1,2 2,3 1,1 1));
  Pose(Point(1 1),0.5)@2001-01-01'));
-- Pose(POINT(1 1),0.5)@2001-01-01


-------------------------------------------------------------------------------
-- Traversed Area
-------------------------------------------------------------------------------

SELECT ST_AsText(traversedArea(trgeometry 'Polygon((0 0, 1 0, 1 1, 0 1, 0 0));
  [Pose(Point(0 0),0)@2026-01-01, Pose(Point(2 0),0)@2026-01-02]'));
-- MULTIPOLYGON(((0 0,1 0,1 1,0 1,0 0)),((2 0,3 0,3 1,2 1,2 0)))
SELECT ST_AsText(convexHull(trgeometry 'Polygon((0 0, 1 0, 1 1, 0 1, 0 0));
  [Pose(Point(0 0),0)@2026-01-01, Pose(Point(2 0),0)@2026-01-02]'));
-- POLYGON((0 0,0 1,3 1,3 0,0 0))


-------------------------------------------------------------------------------
-- Restriction Functions
-------------------------------------------------------------------------------

SELECT asText(atTime(trgeometry 'Polygon((1 1,2 2,3 1,1 1));
  [Pose(Point(1 1),0.2)@2001-01-01, Pose(Point(1 1),0.4)@2001-01-02]',
  timestamptz '2001-01-01'));
-- POLYGON((1 1,2 2,3 1,1 1));Pose(POINT(1 1),0.2)@2001-01-01

-- The body meets the strip 5 <= x <= 6 from the instant its right side reaches
-- it until its left side leaves it.
SELECT getTime(atGeometry(trgeometry 'Polygon((0 0,1 0,1 1,0 1,0 0));
  [Pose(Point(0 0),0)@2001-01-01, Pose(Point(10 0),0)@2001-01-11]',
  geometry 'Polygon((5 -1,6 -1,6 2,5 2,5 -1))'));
-- {[2001-01-05, 2001-01-07]}


-------------------------------------------------------------------------------
-- Comparisons and Spatial Functions
-------------------------------------------------------------------------------

-- A vessel of 20 by 6 meters sails 60 meters to the East during one minute and
-- then turns in place by 90 degrees counterclockwise during the next minute.
DROP TABLE IF EXISTS Ship;
CREATE TABLE Ship(Body) AS SELECT trgeometry
  'Polygon((-10 -3,10 -3,10 3,-10 3,-10 -3));
  [Pose(Point(0 0),0)@2001-01-01 08:00, Pose(Point(60 0),0)@2001-01-01 08:01,
   Pose(Point(60 0),1.5707963267948966)@2001-01-01 08:02]';

SELECT length(Body) AS Length, maxValue(speed(Body)) AS MaxSpeed,
  round(maxValue(angularSpeed(Body))::numeric, 4) AS MaxAngularSpeed
FROM Ship;
-- 60 | 1 | 0.0262

SELECT ST_AsText(valueAtTimestamp(centroid(Body), '2001-01-01 08:01:30'))
    AS Centroid,
  degrees(valueAtTimestamp(yaw(Body), '2001-01-01 08:01:30')) AS Yaw,
  ST_AsText(twCentroid(Body)) AS TWCentroid
FROM Ship;
-- POINT(60 0) | 45 | POINT(45 0)

-- The bow follows a quarter of a circle during the turn; the temporal point
-- interpolates it linearly, the restriction to the instant gives the exact one.
SELECT ST_AsText(valueAtTimestamp(bodyPointTrajectory(Body,
    geometry 'Point(10 0)'), '2001-01-01 08:01:30'), 3) AS Bow,
  ST_AsText(valueAtTimestamp(bodyPointTrajectory(atTime(Body,
    timestamptz '2001-01-01 08:01:30'), geometry 'Point(10 0)'),
    '2001-01-01 08:01:30'), 3) AS ExactBow
FROM Ship;
-- POINT(65 5) | POINT(67.071 7.071)

SELECT round(nearestApproachDistance(Body, Buoy)::numeric, 2) AS Dist,
  getTimestamp(nearestApproachInstant(Body, Buoy)) AS Time,
  ST_AsText(shortestLine(Body, Buoy), 2) AS Line,
  round(nearestApproachDistance(Body::tgeompoint, Buoy)::numeric, 2)
    AS CenterDist
FROM Ship, (SELECT geometry 'Point(80 30)' AS Buoy) AS B;
/* 25.62 | 2001-01-01 08:01:26.407125+00 | LINESTRING(65.79 8.69,80 30) |
   36.06 */


-------------------------------------------------------------------------------
-- Distance Between Moving Objects
-------------------------------------------------------------------------------

SELECT trgeometry 'Polygon((0 0,2 0,2 1,0 1,0 0));
    [Pose(Point(0 0),0)@2026-01-01, Pose(Point(10 0),0)@2026-01-02]'
  |=| geometry 'Point(5 4)' AS Dist;
-- 3
