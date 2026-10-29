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

-- The multibeam soundings of the survey lines off Rostock, read from the CSV
-- files that prep_soundings.sh writes into $DATA/soundings (default:
-- data/soundings below the working directory). The schema 1 of the point
-- clouds states the dimensions of a sounding: its position in EPSG:25832, its
-- topography (positive upwards, in meters), its amplitude, and its beam
-- number. Pings holds one patch per ping, and Swaths one temporal patch per
-- survey line, whose instants are the pings of the line. The positions are
-- transformed ONCE, here, from longitude and latitude to EPSG:25832. MobilityDB
-- writes the schema into the catalog pointcloud_formats of pgPointCloud, which
-- the function pcpatch of pgPointCloud reads (MobilityDB/MobilityDB#3245).
--
--   psql -d ais -f load_soundings.sql
DELETE FROM pointcloud_dimensions WHERE pcid = 1;
DELETE FROM pointcloud_schemas WHERE pcid = 1;
INSERT INTO pointcloud_schemas (pcid, srid, compression, description)
VALUES (1, 25832, 'dimensional', 'Multibeam soundings');
INSERT INTO pointcloud_dimensions (pcid, dim_no, dim_name, interpretation, dim_scale,
  dim_offset, active, description)
VALUES (1, 1, 'X', 'double', 1, 0, true, 'Easting (m)'),
  (1, 2, 'Y', 'double', 1, 0, true, 'Northing (m)'),
  (1, 3, 'Z', 'double', 1, 0, true, 'Topography, positive upwards (m)'),
  (1, 4, 'Amplitude', 'float', 1, 0, true, 'Amplitude of the return'),
  (1, 5, 'Beam', 'uint16_t', 1, 0, true, 'Beam number');

DROP TABLE IF EXISTS SoundingsInput;
CREATE TABLE SoundingsInput (
  Line      text,
  T         float,
  Ping      integer,
  Lon       float,
  Lat       float,
  Z         float,
  Amplitude float,
  Beam      integer );
\copy SoundingsInput FROM PROGRAM 'for f in "${DATA:-data}"/soundings/*.csv; do n=$(basename "$f" .csv); sed "s/^/$n,/" "$f"; done' WITH (FORMAT csv)

DROP TABLE IF EXISTS Pings;
CREATE TABLE Pings AS
WITH Soundings AS (
  SELECT Line, to_timestamp(T) AS T, Beam, Z, Amplitude,
    ST_Transform(ST_SetSRID(ST_MakePoint(Lon, Lat), 4326), 25832) AS Geom
  FROM SoundingsInput )
SELECT Line, T, pcpatch(1, array_agg(v ORDER BY Beam, k)) AS Patch
FROM Soundings,
  unnest(ARRAY[ST_X(Geom), ST_Y(Geom), Z, Amplitude, Beam]) WITH ORDINALITY u(v, k)
GROUP BY Line, T;
CREATE INDEX ON Pings (Line, T);

DROP TABLE IF EXISTS Swaths;
CREATE TABLE Swaths AS
SELECT Line, tpcpatchSeq(array_agg(tpcpatch(Patch, T) ORDER BY T), 'discrete') AS Swath
FROM Pings
GROUP BY Line;

DROP TABLE SoundingsInput;

-- The trip of the survey vessel along each line, from its navigation, one
-- position per ping. A position repeated by consecutive pings is kept once.
DROP TABLE IF EXISTS NavInput;
CREATE TABLE NavInput (
  Line text,
  T    float,
  Lon  float,
  Lat  float );
\copy NavInput FROM PROGRAM 'for f in "${DATA:-data}"/soundings/*.nav; do n=$(basename "$f" .nav); sed "s/^/$n,/" "$f"; done' WITH (FORMAT csv)

DROP TABLE IF EXISTS Tracks;
CREATE TABLE Tracks AS
WITH Fixes AS (
  SELECT Line, to_timestamp(T) AS T, Lon, Lat,
    LAG(Lon) OVER w AS PrevLon, LAG(Lat) OVER w AS PrevLat
  FROM NavInput
  WINDOW w AS (PARTITION BY Line ORDER BY T) )
SELECT Line, tgeompointSeq(array_agg(tgeompoint(
  ST_Transform(ST_SetSRID(ST_MakePoint(Lon, Lat), 4326), 25832), T) ORDER BY T)) AS Trip
FROM Fixes
WHERE PrevLon IS NULL OR Lon <> PrevLon OR Lat <> PrevLat
GROUP BY Line;

DROP TABLE NavInput;

-- The area that the surveys cover, as the coverage of their record at PANGAEA
-- states it in longitude and latitude, about 800 m by 800 m
DROP TABLE IF EXISTS SurveyArea;
CREATE TABLE SurveyArea AS
SELECT ST_Transform(ST_MakeEnvelope(12.104455, 54.182873, 12.116450, 54.190106, 4326),
  25832) AS Geom;
ANALYZE Pings;
ANALYZE Swaths;
ANALYZE Tracks;
