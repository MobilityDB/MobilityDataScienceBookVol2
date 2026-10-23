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

-- On v1.0-mini, three scenes pitch by more than three degrees: scene-0916 up to 4.59 degrees,
-- scene-0103 up to 3.29 and scene-1094 up to 3.21; export_nuscenes.py draws the pitch of
-- scene-0916 (nus_pitch).
WITH Attitude(Name, P) AS (
  SELECT s.Name, degrees(pitch(e.Trip))
  FROM EgoTrip e JOIN Scene s ON e.SceneId = s.SceneId )
SELECT Name, maxValue(abs(P)) AS MaxPitch
FROM Attitude WHERE abs(P) ?> 3;

-- The pitch has step interpolation
SELECT s.Name, interp(degrees(pitch(e.Trip)))
FROM EgoTrip e JOIN Scene s ON e.SceneId = s.SceneId
WHERE s.Name LIKE '%0916';
-- scene-0916 | Step

-- The same instants with linear interpolation
SELECT s.Name, tfloatSeq(instants(pitch(e.Trip)), 'Linear') AS Pitch
FROM EgoTrip e JOIN Scene s ON e.SceneId = s.SceneId
WHERE s.Name LIKE '%0916';


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
  ST_Area(traversedArea(Trip, true)) AS Swept,
  ST_Area(traversedArea(Trip, true)) / ST_Area(Trip::geometry) AS Ratio
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
SELECT Category, COUNT(*) AS Moving, COUNT(*) FILTER (WHERE
  atSpanset(D, floatspanset '{(5,355),(365,720)}') IS NOT NULL) AS Differs
FROM Diff GROUP BY Category ORDER BY Moving DESC;
-- human.pedestrian.adult  144  112
-- vehicle.car             134   62
-- vehicle.bus.rigid        11    9
