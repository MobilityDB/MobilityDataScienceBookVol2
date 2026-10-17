-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- Queries over the nuScenes autonomous-driving dataset
--
-- Run load_nuscenes.sql first; it builds EgoTrip, EgoBody, ObjectTrip and SensorMount.
--
-- Last run against PostgreSQL 18.1, PostGIS 3.6.1, MobilityDB 1.4.
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- The Vehicle as a Temporal Pose
-------------------------------------------------------------------------------

WITH Attitude(SceneId, P) AS (
  SELECT SceneId, degrees(pitch(tpose(Trip))) FROM EgoTrip )
SELECT SceneId, maxValue(abs(P)) AS MaxPitch
FROM Attitude WHERE abs(P) ?> 5;


-------------------------------------------------------------------------------
-- Surrounding Traffic as Rigid Geometries
-------------------------------------------------------------------------------

-- Body-to-body clearance. MobilityDB 1.4 refuses distance between two rigid
-- geometries in 3D ("Distance computation in 3D is not currently supported"),
-- so the bodies are projected to the ground plane first: a 2D pose is exactly
-- the yaw, which is what a clearance on the road surface asks for anyway.
DROP TABLE IF EXISTS EgoBody2D CASCADE;
CREATE TABLE EgoBody2D(SceneId, Body) AS
SELECT SceneId, trgeometry(ST_MakeEnvelope(-2.35, -0.9, 2.35, 0.9),
  tposeSeq(array_agg(tpose(pose(ST_Point(ST_X(point(P)), ST_Y(point(P))),
    yaw(P)), T) ORDER BY T)))
FROM ( SELECT SceneId, getTimestamp(i) AS T, getValue(i) AS P
       FROM EgoTrip, unnest(instants(Trip)) AS i ) x
GROUP BY SceneId;

DROP TABLE IF EXISTS ObjectTrip2D CASCADE;
CREATE TABLE ObjectTrip2D(SceneId, InstanceId, Category, Trip) AS
SELECT SceneId, InstanceId, Category,
  trgeometry(ST_MakeEnvelope(-Len/2, -Wid/2, Len/2, Wid/2),
    tposeSeq(array_agg(tpose(pose(ST_Point(ST_X(point(P)), ST_Y(point(P))),
      yaw(P)), T) ORDER BY T)))
FROM ( SELECT o.SceneId, o.InstanceId, o.Category,
         ST_XMax(o.Trip::geometry) - ST_XMin(o.Trip::geometry) AS Len,
         ST_YMax(o.Trip::geometry) - ST_YMin(o.Trip::geometry) AS Wid,
         getTimestamp(i) AS T, getValue(i) AS P
       FROM ObjectTrip o, unnest(instants(tpose(o.Trip))) AS i ) x
GROUP BY SceneId, InstanceId, Category, Len, Wid;

SELECT o.InstanceId, o.Category,
  nearestApproachInstant(e.Body, o.Trip) AS AtInstant,
  e.Body |=| o.Trip AS Clearance
FROM EgoBody2D e JOIN ObjectTrip2D o USING (SceneId)
WHERE e.Body |=| o.Trip < 1.0
ORDER BY Clearance;
-- vehicle.car                 0.00
-- vehicle.truck               0.50
-- movable_object.trafficcone  0.63

SELECT InstanceId, Category,
  ST_Area(traversedArea(Trip)) AS Swept,
  ST_Area(traversedArea(Trip)) / ST_Area(Trip::geometry) AS Ratio
FROM ObjectTrip
ORDER BY Ratio DESC;


-------------------------------------------------------------------------------
-- The Sensor Rig as a Pose Chain
-------------------------------------------------------------------------------

SELECT ST_AsText(applyPose(ST_MakePoint(12.4, -1.8, 0.3),
  applyPose(s.Mounting,
    valueAtTimestamp(e.Trip, timestamptz '2018-07-24 03:28:48'))))
FROM SensorMount s JOIN EgoTrip e USING (SceneId)
WHERE s.Channel = 'LIDAR_TOP';
-- POINT Z (338.685 670.422 2.241)

SELECT o.InstanceId, o.Category, ST_AsText(applyPose(
  valueAtTimestamp(o.Trip, timestamptz '2018-07-24 03:28:48'),
  poseInverse(applyPose(s.Mounting,
    valueAtTimestamp(e.Trip, timestamptz '2018-07-24 03:28:48')))))
FROM ObjectTrip o, SensorMount s, EgoTrip e
WHERE s.Channel = 'CAM_FRONT' AND o.SceneId = e.SceneId;


-------------------------------------------------------------------------------
-- What the Second Dataset Adds
-------------------------------------------------------------------------------

WITH Diff(Category, D) AS (
  SELECT Category, abs(degrees(yaw(Trip)) -
    (90 - degrees(azimuth(tgeompoint(Trip)))))
  FROM ObjectTrip WHERE length(tgeompoint(Trip)) > 5 )
SELECT Category, count(*) AS Moving, count(*) FILTER (WHERE
  atSpanset(D, floatspanset '{(5,355),(365,720)}') IS NOT NULL) AS Differs
FROM Diff GROUP BY Category ORDER BY Moving DESC;
-- human.pedestrian.adult  144  112
-- vehicle.car             134   62
-- vehicle.bus.rigid        11    9
