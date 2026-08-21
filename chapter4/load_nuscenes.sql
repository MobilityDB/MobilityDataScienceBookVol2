-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Loading nuScenes into MobilityDB
--
-- Reads the JSON tables of a nuScenes release with PostgreSQL's own JSON
-- facilities, and builds the temporal poses and temporal rigid geometries
-- used in the chapter on temporal poses.
--
-- Usage, with the directory holding the JSON files (for the mini release,
-- <root>/v1.0-mini):
--
--   psql -d mobilitydb -v dir=/path/to/v1.0-mini -f load_nuscenes.sql
--
-- pg_read_file reads on the SERVER, so the files must be readable by the
-- server process and the role needs pg_read_server_files (a superuser has
-- it). Where that is not available, replace the staging INSERT below with a
-- client-side read: in psql, \set doc `cat /path/ego_pose.json` and then
-- SELECT :'doc'::jsonb.
--
-- Run against nuScenes v1.0-mini with PostgreSQL 18.1, PostGIS 3.6.1 and
-- MobilityDB 1.4. It loads 10 scenes, 404 samples, 31206 ego poses, 18538
-- annotations, and builds 10 temporal poses, 881 temporal rigid geometries
-- and 120 sensor mountings. yaw(trgeometry) requires a MobilityDB built after
-- the rotation -> yaw rename; before it, the function is rotation(trgeometry).
-------------------------------------------------------------------------------

\set ON_ERROR_STOP on

-------------------------------------------------------------------------------
-- 1. Staging: one row per JSON file, the whole file as a single jsonb value
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS NsRaw CASCADE;
CREATE TABLE NsRaw(Name text PRIMARY KEY, Doc jsonb);

INSERT INTO NsRaw(Name, Doc)
SELECT f, pg_read_file(:'dir' || '/' || f || '.json')::jsonb
FROM unnest(ARRAY['scene', 'sample', 'sample_data', 'ego_pose',
  'sample_annotation', 'instance', 'category', 'calibrated_sensor',
  'sensor']) AS f;

-- Each file is a JSON array of records, so the row count is its length.
SELECT Name, jsonb_array_length(Doc) AS Records FROM NsRaw ORDER BY Name;

-------------------------------------------------------------------------------
-- 2. The nuScenes tables, expanded from JSON
--
-- Two conventions are applied here, once, rather than being left to every
-- later query:
--   * rotation is [w, x, y, z], scalar part first, which is the order a
--     MobilityDB pose literal uses, so the components pass through unchanged;
--   * size is [width, length, height] -- NOT length first. Unpacking it in
--     the order it appears rotates every object by a right angle, and the
--     boxes stay plausible rectangles, so the error is silent.
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS Scene CASCADE;
CREATE TABLE Scene AS
SELECT e->>'token' AS SceneId, e->>'name' AS Name,
  (e->>'nbr_samples')::int AS NbrSamples
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'scene';
ALTER TABLE Scene ADD PRIMARY KEY (SceneId);

DROP TABLE IF EXISTS Sample CASCADE;
CREATE TABLE Sample AS
SELECT e->>'token' AS SampleId, e->>'scene_token' AS SceneId,
  to_timestamp((e->>'timestamp')::bigint / 1e6) AS T
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'sample';
ALTER TABLE Sample ADD PRIMARY KEY (SampleId);
CREATE INDEX Sample_Scene_Idx ON Sample(SceneId);

DROP TABLE IF EXISTS Category CASCADE;
CREATE TABLE Category AS
SELECT e->>'token' AS CategoryId, e->>'name' AS Name
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'category';
ALTER TABLE Category ADD PRIMARY KEY (CategoryId);

DROP TABLE IF EXISTS Instance CASCADE;
CREATE TABLE Instance AS
SELECT e->>'token' AS InstanceId, e->>'category_token' AS CategoryId
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'instance';
ALTER TABLE Instance ADD PRIMARY KEY (InstanceId);

DROP TABLE IF EXISTS Sensor CASCADE;
CREATE TABLE Sensor AS
SELECT e->>'token' AS SensorId, e->>'channel' AS Channel,
  e->>'modality' AS Modality
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'sensor';
ALTER TABLE Sensor ADD PRIMARY KEY (SensorId);

-- Ego pose: position and orientation of the vehicle in the global frame.
-- z is 0 throughout the release; the orientation is nonetheless a full
-- quaternion, since the platform pitches and rolls.
DROP TABLE IF EXISTS EgoPoseRaw CASCADE;
CREATE TABLE EgoPoseRaw AS
SELECT e->>'token' AS EgoPoseId,
  (e->'translation'->>0)::float AS X,
  (e->'translation'->>1)::float AS Y,
  (e->'translation'->>2)::float AS Z,
  (e->'rotation'->>0)::float AS QW,
  (e->'rotation'->>1)::float AS QX,
  (e->'rotation'->>2)::float AS QY,
  (e->'rotation'->>3)::float AS QZ,
  to_timestamp((e->>'timestamp')::bigint / 1e6) AS T
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'ego_pose';
ALTER TABLE EgoPoseRaw ADD PRIMARY KEY (EgoPoseId);

-- sample_data links an ego pose to a sample, and hence to a scene.
DROP TABLE IF EXISTS SampleData CASCADE;
CREATE TABLE SampleData AS
SELECT e->>'token' AS SampleDataId, e->>'sample_token' AS SampleId,
  e->>'ego_pose_token' AS EgoPoseId,
  e->>'calibrated_sensor_token' AS CalibratedSensorId,
  (e->>'is_key_frame')::boolean AS IsKeyFrame
FROM NsRaw r, jsonb_array_elements(r.Doc) e WHERE r.Name = 'sample_data';
ALTER TABLE SampleData ADD PRIMARY KEY (SampleDataId);
CREATE INDEX SampleData_EgoPose_Idx ON SampleData(EgoPoseId);

DROP TABLE IF EXISTS CalibratedSensor CASCADE;
CREATE TABLE CalibratedSensor AS
SELECT e->>'token' AS CalibratedSensorId, e->>'sensor_token' AS SensorId,
  (e->'translation'->>0)::float AS X,
  (e->'translation'->>1)::float AS Y,
  (e->'translation'->>2)::float AS Z,
  (e->'rotation'->>0)::float AS QW,
  (e->'rotation'->>1)::float AS QX,
  (e->'rotation'->>2)::float AS QY,
  (e->'rotation'->>3)::float AS QZ
FROM NsRaw r, jsonb_array_elements(r.Doc) e
WHERE r.Name = 'calibrated_sensor';
ALTER TABLE CalibratedSensor ADD PRIMARY KEY (CalibratedSensorId);

-- Annotations. Note the order of the size components.
DROP TABLE IF EXISTS SampleAnnotation CASCADE;
CREATE TABLE SampleAnnotation AS
SELECT e->>'token' AS AnnotationId, e->>'sample_token' AS SampleId,
  e->>'instance_token' AS InstanceId,
  (e->'translation'->>0)::float AS X,
  (e->'translation'->>1)::float AS Y,
  (e->'translation'->>2)::float AS Z,
  (e->'size'->>0)::float AS Width,     -- size[0] is the WIDTH
  (e->'size'->>1)::float AS Length,    -- size[1] is the LENGTH
  (e->'size'->>2)::float AS Height,
  (e->'rotation'->>0)::float AS QW,
  (e->'rotation'->>1)::float AS QX,
  (e->'rotation'->>2)::float AS QY,
  (e->'rotation'->>3)::float AS QZ
FROM NsRaw r, jsonb_array_elements(r.Doc) e
WHERE r.Name = 'sample_annotation';
ALTER TABLE SampleAnnotation ADD PRIMARY KEY (AnnotationId);
CREATE INDEX SampleAnnotation_Sample_Idx ON SampleAnnotation(SampleId);

-------------------------------------------------------------------------------
-- 3. The MobilityDB tables used in the chapter
-------------------------------------------------------------------------------

-- The vehicle as a temporal pose, one per scene. Ego poses are recorded for
-- every sensor reading, so the same instant can appear more than once; DISTINCT
-- keeps one pose per instant, which is what a temporal sequence requires.
DROP TABLE IF EXISTS EgoTrip CASCADE;
CREATE TABLE EgoTrip(SceneId, Trip) AS
WITH EgoPose(SceneId, T, X, Y, Z, QW, QX, QY, QZ) AS (
  SELECT DISTINCT ON (s.SceneId, p.T)
    s.SceneId, p.T, p.X, p.Y, p.Z, p.QW, p.QX, p.QY, p.QZ
  FROM EgoPoseRaw p
    JOIN SampleData d ON d.EgoPoseId = p.EgoPoseId
    JOIN Sample s ON s.SampleId = d.SampleId
  ORDER BY s.SceneId, p.T )
SELECT SceneId, tposeSeq(array_agg(
  tpose(pose(ST_MakePoint(X, Y, Z), QW, QX, QY, QZ), T) ORDER BY T))
FROM EgoPose
GROUP BY SceneId;

-- The recording vehicle given a footprint, so that it can be compared body to
-- body with the traffic around it. The dimensions are a property of the
-- platform rather than of the data.
--
-- ST_Force3D is required, not cosmetic: the reference geometry of a temporal
-- rigid geometry must have the same dimension as its pose, and these poses
-- are 3D. Without it the constructor rejects the pair with
--   ERROR: Dimension of geometry and pose must correspond
-- The footprint lies in the plane z = 0 of the body frame, so the vehicle
-- floor tilts with the platform, which is what the orientation describes.
DROP TABLE IF EXISTS EgoBody CASCADE;
CREATE TABLE EgoBody(SceneId, Body) AS
SELECT SceneId,
  trgeometry(ST_Force3D(ST_MakeEnvelope(-2.35, -0.9, 2.35, 0.9)), Trip)
FROM EgoTrip;

-- Every annotated object as a temporal rigid geometry. The footprint is
-- centred on the origin because the annotation's translation is the centre of
-- the box, so the centre of rotation is the centroid.
DROP TABLE IF EXISTS ObjectTrip CASCADE;
CREATE TABLE ObjectTrip(SceneId, InstanceId, Category, Trip) AS
SELECT s.SceneId, a.InstanceId, c.Name,
  trgeometry(
    ST_Force3D(
      ST_MakeEnvelope(-a.Length / 2, -a.Width / 2, a.Length / 2, a.Width / 2)),
    tposeSeq(array_agg(
      tpose(pose(ST_MakePoint(a.X, a.Y, a.Z), a.QW, a.QX, a.QY, a.QZ), s.T)
      ORDER BY s.T)))
FROM SampleAnnotation a
  JOIN Sample s ON s.SampleId = a.SampleId
  JOIN Instance i ON i.InstanceId = a.InstanceId
  JOIN Category c ON c.CategoryId = i.CategoryId
GROUP BY s.SceneId, a.InstanceId, c.Name, a.Length, a.Width
HAVING count(*) > 1;

-- The mounting pose of each instrument, in the body frame of the vehicle.
-- A calibration is per scene, so the channel alone does not identify a row.
DROP TABLE IF EXISTS SensorMount CASCADE;
CREATE TABLE SensorMount(SceneId, Channel, Modality, Mounting) AS
SELECT DISTINCT ON (s.SceneId, se.Channel)
  s.SceneId, se.Channel, se.Modality,
  pose(ST_MakePoint(cs.X, cs.Y, cs.Z), cs.QW, cs.QX, cs.QY, cs.QZ)
FROM CalibratedSensor cs
  JOIN Sensor se ON se.SensorId = cs.SensorId
  JOIN SampleData d ON d.CalibratedSensorId = cs.CalibratedSensorId
  JOIN Sample s ON s.SampleId = d.SampleId
ORDER BY s.SceneId, se.Channel;

-------------------------------------------------------------------------------
-- 4. Checks
-------------------------------------------------------------------------------

SELECT 'scenes' AS Item, count(*) FROM Scene
UNION ALL SELECT 'ego trips', count(*) FROM EgoTrip
UNION ALL SELECT 'object trips', count(*) FROM ObjectTrip
UNION ALL SELECT 'sensor mounts', count(*) FROM SensorMount;

-- A vehicle is normally longer than it is wide, so this counts the exceptions
-- rather than demanding none. Reading size as [length, width, height] would
-- make nearly every vehicle an exception; reading it correctly leaves a
-- handful of genuinely wide objects. On v1.0-mini the answer is 19 of 9648
-- vehicle annotations, and all 19 are one detached box trailer measuring
-- 2.166 by 1.787 -- which is really wider than it is long. A result in the
-- thousands means the components were unpacked in the wrong order.
SELECT count(*) FILTER (WHERE a.Width > a.Length) AS WiderThanLong,
  count(*) AS VehicleAnnotations
FROM SampleAnnotation a JOIN Instance i USING (InstanceId)
  JOIN Category c ON c.CategoryId = i.CategoryId
WHERE c.Name LIKE 'vehicle%';

-- Every stored quaternion should have unit norm.
SELECT count(*) AS NonUnitQuaternions
FROM SampleAnnotation
WHERE abs(sqrt(QW * QW + QX * QX + QY * QY + QZ * QZ) - 1) > 1e-6;

-- The orientation of the traffic should NOT follow its direction of travel,
-- which is what makes this dataset carry a pose at all. Two corrections are
-- needed before the two angles can be compared, and both are easy to omit:
--
--   * they use different conventions. yaw is measured counter-clockwise from
--     the x axis, azimuth clockwise from north, so the course in the yaw
--     convention is 90 - azimuth. Comparing them raw reports a disagreement
--     almost everywhere, for no reason but the convention.
--   * the difference wraps. After the conversion it lies in (-270, 450), so
--     a difference near 360 is really an agreement, and one just above 365 is
--     a genuine disagreement that a single band would miss. The span set names
--     both intervals of real disagreement.
--
-- Stationary objects are excluded: with no displacement the azimuth is noise.
-- On v1.0-mini, 195 of the 310 objects that move more than 5 m turn away from
-- their course by more than 5 degrees at some instant -- 112 of 144
-- pedestrians, who face where they look rather than where they walk, against
-- 62 of 134 cars.
WITH Diff(Category, D) AS (
  SELECT Category,
    abs(degrees(yaw(Trip)) - (90 - degrees(azimuth(tgeompoint(Trip)))))
  FROM ObjectTrip WHERE length(tgeompoint(Trip)) > 5 )
SELECT count(*) AS MovingObjects,
  count(*) FILTER (WHERE atSpanset(D, floatspanset '{(5, 355), (365, 720)}')
    IS NOT NULL) AS OrientationDiffersFromCourse
FROM Diff;

-------------------------------------------------------------------------------
