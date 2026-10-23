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

-- -----------------------------------------------------------------------------
-- The queries of the use case on the wind fields of the 2024 Atlantic storms
-- (Sect. "Temporal Geometries and Temporal Geographies" of Chapter 3), in the
-- order of the chapter, with the answer of each one as a comment. They run on
-- the tables built by storms.sql with year=2024.
--
-- Usage: psql -d <database> -f storms_queries.sql
-- -----------------------------------------------------------------------------
-- The timestamps of the data and of the answers are in UTC
SET TimeZone = 'UTC';

-- A temporal geometry refuses the linear interpolation
SELECT tgeometry 'Interp=Linear;[Point(0 0)@2001-01-01, Point(1 1)@2001-01-02]';
-- ERROR:  The temporal type cannot have linear interpolation

-- The nearest approach distance of the same values as a temporal geometry, a
-- Cartesian distance in the plane of longitudes and latitudes that corresponds
-- to no true angular difference, and as a temporal geography, in meters
SELECT
  round(nearestApproachDistance(tgeometry 'SRID=4326;[Polygon((4.35 50.84,
    4.40 50.84,4.40 50.88,4.35 50.84))@2001-01-01, Point(4.37 50.85)@2001-01-02]',
    geometry 'SRID=4326;Point(4.45 50.84)')::numeric, 4) AS Planar,
  round(nearestApproachDistance(tgeography 'SRID=4326;[Polygon((4.35 50.84,
    4.40 50.84,4.40 50.88,4.35 50.84))@2001-01-01, Point(4.37 50.85)@2001-01-02]',
    geography 'Point(4.45 50.84)')::numeric, 1) AS Geodetic;
-- 0.0500 | 3521.9

-- The SRID of a wind field before and after each conversion
SELECT srid(Storm), srid(Storm::tgeometry), srid(transform(Storm::tgeometry, 32617))
FROM Storms2024_tgeo
WHERE Name = 'Milton' AND Radii = 64;
-- 4326 | 4326 | 32617

-- What was the extent of the hurricane-force winds of Milton on October 10,
-- 2024, at 2:30?
SELECT round((ST_Area(valueAtTimestamp(Storm, '2024-10-10 02:30'))
  / 1e6)::numeric) AS AreaKm2
FROM Storms2024_tgeo
WHERE Name = 'Milton' AND Radii = 64;
-- 9660

-- Which storms brought winds of at least 34 knots to Tampa, and when?
SELECT Name, Radii, whenTrue(tIntersects(Storm, geography 'Point(-82.46 27.95)'))
FROM Storms2024_tgeo
WHERE eIntersects(Storm, geography 'Point(-82.46 27.95)')
ORDER BY Name, Radii;
/* Debby  | 34 | {[2024-08-04 18:00:00+00, 2024-08-05 12:00:00+00)}
   Helene | 34 | {[2024-09-26 06:00:00+00, 2024-09-27 12:00:00+00)}
   Helene | 50 | {[2024-09-27 00:00:00+00, 2024-09-27 05:00:00+00)}
   Milton | 34 | {[2024-10-09 18:00:00+00, 2024-10-10 12:00:00+00)}
   Milton | 50 | {[2024-10-10 00:00:00+00, 2024-10-10 12:00:00+00)} */

-- How close to Tampa did the hurricane-force winds of Milton come, and when?
SELECT
  round((nearestApproachDistance(Storm,
    geography 'Point(-82.46 27.95)') / 1000)::numeric, 1) AS GeodeticKm,
  round((nearestApproachDistance(transform(Storm::tgeometry, 32617),
    ST_Transform(ST_Point(-82.46, 27.95, 4326), 32617)) / 1000)::numeric, 1)
    AS UtmKm,
  getTimestamp(nearestApproachInstant(Storm,
    geography 'Point(-82.46 27.95)')) AS Instant
FROM Storms2024_tgeo
WHERE Name = 'Milton' AND Radii = 64;
-- 20.5 | 20.5 | 2024-10-10 00:00:00+00

-- Which three storms swept the largest area with hurricane-force winds? MEOS has
-- no union on the ellipsoid, so the union is computed on the temporal geometry
SELECT Name,
  round((ST_Area(traversedArea(Storm::tgeometry, true)::geography) / 1e6)::numeric)
    AS AreaKm2
FROM Storms2024_tgeo
WHERE Radii = 64
ORDER BY AreaKm2 DESC
LIMIT 3;
/* Kirk    | 421047
   Ernesto | 269942
   Beryl   | 172013 */

-- The wind swath that NOAA publishes for Kirk, for comparison
SELECT round((ST_Area(ST_Union(s.Geom)::geography) / 1e6)::numeric) AS AreaKm2
FROM StormSwath s
WHERE s.StormId = 'AL122024' AND s.Radii = 64;
-- 578907
