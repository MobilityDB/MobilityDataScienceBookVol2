-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- The OGC GeoPose 1.0 examples
--
-- Self-contained. The GeoPose JSON documents of the chapter are in geopose_examples.json.
--
-- Last run against PostgreSQL 18.1, PostGIS 3.6.1, MobilityDB 1.4.
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Naming a Frame
-------------------------------------------------------------------------------

SELECT frame_id, authority, code, name, srid, is_geographic
FROM geopose_frames ORDER BY frame_id;
/* 1 | EPSG         | 4326            | WGS-84 geographic  | 4326 | t
   2 | EPSG         | 4978            | WGS-84 ECEF        | 4978 | f
   3 | OGC          | LTP             | Local Tangent Plane|      | f
   4 | OGC          | BODY            | Right-handed body  |      | f
   5 | /geopose/1.0 | LTP-ENU         | Series outer frame |      | f
   6 | /geopose/1.0 | RotateTranslate | Series inner frame |      | f */

SELECT geoPoseFrameName(3), geoPoseFrameSRID(3), geoPoseFrameIsGeographic(1);
-- Local Tangent Plane (East-North-Up) |  | t


-------------------------------------------------------------------------------
-- GeoPose in MobilityDB
-------------------------------------------------------------------------------

SELECT asGeoPose(poseFromGeoPose('{"position":{"lat":47,"lon":8,"h":1500},
  "quaternion":{"x":0,"y":0,"z":0.7071067811865476,
  "w":0.7071067811865476}}'), 0, 6);
/* {"position":{"lat":47,"lon":8,"h":1500},
   "quaternion":{"x":0,"y":0,"z":0.707107,"w":0.707107}} */

SELECT asGeoPose(poseFromGeoPose('{"position":{"lat":47,"lon":8,"h":1500},
  "quaternion":{"x":0,"y":0,"z":0.7071067811865476,
  "w":0.7071067811865476}}'), 1, 6);
-- {"position":{"lat":47,"lon":8,"h":1500},"angles":{"yaw":90,"pitch":0,"roll":0}}
SELECT asGeoPose(poseFromGeoPose('{"position":{"lat":47,"lon":8,"h":1500},
  "angles":{"yaw":90,"pitch":0,"roll":0}}'), 0, 6);
/* {"position":{"lat":47,"lon":8,"h":1500},
   "quaternion":{"x":0,"y":0,"z":0.707107,"w":0.707107}} */
SELECT asGeoPose(poseFromGeoPose('{"position":{"lat":47,"lon":8,"h":1500},
  "angles":{"yaw":30,"pitch":45,"roll":60}}'), 1, 6);
/* {"position":{"lat":47,"lon":8,"h":1500},
   "angles":{"yaw":30,"pitch":45,"roll":60}} */

SELECT pose '{"position":{"lat":1.0,"lon":1.0,"h":1.0},
  "quaternion":{"x":0.5,"y":0.5,"z":0.5,"w":0.5}}';
-- GEODPOSE(0101000020E6100000..., 0.5, 0.5, 0.5, 0.5)


-------------------------------------------------------------------------------
-- Temporal GeoPose
-------------------------------------------------------------------------------

SELECT asGeoPose(tpose 'Geodpose(Point(8 47), 0)@2026-01-01', 0, 6);
/* {"position":{"lat":47,"lon":8,"h":0},
   "quaternion":{"x":0,"y":0,"z":0,"w":1},"validTime":1767254400000} */

SELECT asGeoPose(tpose '[Geodpose(Point(0 0), 0)@2026-01-01,
  Geodpose(Point(0 0), 0.5)@2026-01-02]', 0, 6);
/* {"header":{"poseCount":2,"startInstant":1767254400000,
     "stopInstant":1767340800000,
     "transitionModel":{"authority":"/geopose/1.0","id":"interpolate",
       "parameters":"interpolation=Linear"}},
   "interPoseDuration":86400000,
   "outerFrame":{"authority":"/geopose/1.0","id":"LTP-ENU",
     "parameters":"longitude=0&latitude=0&height=0&crs=EPSG:4979"},
   "innerFrameSeries":[
     {"authority":"/geopose/1.0","id":"RotateTranslate",
      "parameters":"translation=[0, 0, 0]&rotation=[1, 0, 0, 0]"},
     {"authority":"/geopose/1.0","id":"RotateTranslate",
      "parameters":"translation=[0, 0, 0]&rotation=[0.968912, 0, 0, 0.247404]"}],
   "trailer":{"poseCount":2}} */

SELECT asText(tposeFromGeoPose(asGeoPose(
  tpose 'Geodpose(Point(8 47), 0)@2026-01-01', 0, 6)));
-- GeodPose(POINT Z (8 47 0),1,0,0,0)@2026-01-01


-------------------------------------------------------------------------------
-- Chains of Frames
-------------------------------------------------------------------------------

SELECT asEWKT(posechain 'PoseChain(Pose(Point(0 0), 0), Pose(Point(10 0), 0))');
-- PoseChain(Pose(POINT(0 0),0),Pose(POINT(10 0),0))
SELECT asEWKT(posechain 'SRID=3812;PoseChain(Pose(Point(1 2 3), 1, 0, 0, 0),
  Pose(Point(0 0 1), 1, 0, 0, 0))');
/* SRID=3812;PoseChain(Pose(POINT Z (1 2 3),1,0,0,0),
   Pose(POINT Z (0 0 1),1,0,0,0)) */
SELECT asEWKT(posechain 'SRID=4326;PoseChain(GeodPose(Point(8 47 0), 1, 0, 0, 0))');
-- SRID=4326;PoseChain(GeodPose(POINT Z (8 47 0),1,0,0,0))

SELECT numPoses(posechain 'PoseChain(Pose(Point(0 0), 0),
  Pose(Point(20 0), 0), Pose(Point(0 0), 1.5707963267948966))');
-- 3
SELECT asEWKT(pose(posechain 'PoseChain(Pose(Point(0 0), 0),
  Pose(Point(20 0), 0), Pose(Point(0 0), 1.5707963267948966))', 2));
-- Pose(POINT(20 0),0)
