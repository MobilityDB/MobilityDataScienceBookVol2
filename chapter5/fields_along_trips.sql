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

-- Reading Fields along Trajectories: the value of a raster along a trip, nearest
-- and bilinear values, tiled rasters, and fields that change over time, on the
-- raster Depth of map_algebra.sql. The listings of the chapter omit the SRID
-- (EPSG:25832) of the geometries and the time zone of the timestamps; the
-- queries below state the SRID and print with asText. Each listing is preceded
-- by its printed answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Listing: the depth under a vessel crossing the third row of pixels
/* Interp=Step;[9@2025-01-01 08:00:00, 10@2025-01-01 08:01:20,
   12@2025-01-01 08:03:00, 14@2025-01-01 08:04:40, 14@2025-01-01 08:06:00] */
SELECT asText(rasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast))
FROM Depth;

\echo == Listing: a trip through three pixel corners
/* Interp=Step;[12@2025-01-01 08:00:00, 13@2025-01-01 08:01:00,
   12@2025-01-01 08:03:00, 11@2025-01-01 08:05:00, 11@2025-01-01 08:06:00] */
SELECT asText(rasterValue(tgeompoint '[SRID=25832;Point(600050 6400350)@2025-01-01 08:00,
  SRID=25832;Point(600350 6400050)@2025-01-01 08:06]', Rast))
FROM Depth;

\echo == Listing: restriction to, and ever and always, a range of values
/* {[Point(600020 6400150)@2025-01-01 08:00:00,
     Point(600200 6400150)@2025-01-01 08:03:00)} */
SELECT asText(atRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)'))
FROM Depth;
-- t | f
SELECT eRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)'),
  aRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)')
FROM Depth;

\echo == Listing: the bilinear value at a pixel corner
-- {12.5@2025-01-01 08:00:00}
SELECT asText(rasterValue(tgeompoint 'SRID=25832;Point(600100 6400300)@2025-01-01 08:00',
  Rast, 1, true, 'bilinear'))
FROM Depth;

\echo == Listing: the bilinear value along a moving trip is refused
-- ERROR: A bilinear value varies quadratically along a moving trajectory, which a
--   temporal float cannot state
\set ON_ERROR_STOP 0
SELECT rasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, 1, true, 'bilinear')
FROM Depth;
\set ON_ERROR_STOP 1

\echo == Listing: a tiled raster read along every trip (number of vessels read)
SELECT COUNT(*) AS Vessels FROM (
  SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, b.Rast))
  FROM Ships s, Bathymetry b
  WHERE ST_Intersects(b.Rast, trajectory(s.Trip))
  GROUP BY s.MMSI ) t;

\echo == Listing: two hourly steps of a salinity field
DROP TABLE IF EXISTS Salinity, Trips;
CREATE TABLE Salinity(ValidTime tstzspan, Rast raster);
INSERT INTO Salinity
SELECT tstzspan '[2025-01-01 08:00, 2025-01-01 09:00)', ST_SetValues(
  ST_AddBand(ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
    '32BF'::text, 0, -9999),
  1, 1, 1, ARRAY[[20,21,22,23],[20,21,22,23],[20,21,22,23],[20,21,22,23]]::float[][])
UNION ALL
SELECT tstzspan '[2025-01-01 09:00, 2025-01-01 10:00)', ST_SetValues(
  ST_AddBand(ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
    '32BF'::text, 0, -9999),
  1, 1, 1, ARRAY[[24,25,26,27],[24,25,26,27],[24,25,26,27],[24,25,26,27]]::float[][]);

\echo == Listing: the value of each step held constant during its period
/* Interp=Step;{[20@2025-01-01 08:40:00, 21@2025-01-01 08:48:00,
   22@2025-01-01 08:58:00, 26@2025-01-01 09:00:00, 27@2025-01-01 09:08:00,
   27@2025-01-01 09:16:00]} */
CREATE TABLE Trips(Trip tgeompoint);
INSERT INTO Trips VALUES (tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:40,
  SRID=25832;Point(600380 6400150)@2025-01-01 09:16]');
SELECT asText(mergeAgg(rasterValue(atTime(t.Trip, s.ValidTime), s.Rast)
  ORDER BY s.ValidTime))
FROM Trips t, Salinity s
WHERE t.Trip && s.ValidTime;

\echo == Listing: nearest in space and linear in time between the steps at 08:00 and 09:00
/* {[20.667@2025-01-01 08:10:00, 21.2@2025-01-01 08:18:00),
   [22.2@2025-01-01 08:18:00, 22.867@2025-01-01 08:28:00),
   [23.867@2025-01-01 08:28:00, 24.533@2025-01-01 08:38:00),
   [25.533@2025-01-01 08:38:00, 26.067@2025-01-01 08:46:00]}  (rounded to three decimals) */
TRUNCATE Trips;
INSERT INTO Trips VALUES (tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:10,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:46]');
WITH Steps AS (
  SELECT
    (SELECT Rast FROM Salinity WHERE lower(ValidTime) = '2025-01-01 08:00') AS R1,
    (SELECT Rast FROM Salinity WHERE lower(ValidTime) = '2025-01-01 09:00') AS R2 )
SELECT asText(rasterValue(Trip, R1) + (rasterValue(Trip, R2) - rasterValue(Trip, R1)) *
  atTime(tfloat '[0@2025-01-01 08:00, 1@2025-01-01 09:00]', getTime(Trip)), 3)
FROM Trips, Steps;
