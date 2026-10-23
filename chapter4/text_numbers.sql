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
-- The numbers the text of the AIS use case quotes and no listing prints
--
-- Reads the tables of the AIS use case (ShipsRigid, ShipShape, AISCleanPoly,
-- ShipBoxes, built by ais_poses.sql), the table Vessels of the AIS database, and
-- the turbines of the Anholt wind farm (Turbines, built by load_turbines.sql).
-- Run against the AIS database:
--   psql -d ais -f text_numbers.sql
--
-- Last run against PostgreSQL 18.6, PostGIS 3.6.4, MobilityDB 1.4.
-------------------------------------------------------------------------------

\timing on
SET TimeZone = 'UTC';

-------------------------------------------------------------------------------
-- Close encounters: the vessels within 100 m of each other, the candidate
-- pairs read from the split boxes of the trips (ShipBoxes), as the listings of
-- the chapter read them: two vessels come within 100 m only if a box of one,
-- expanded by 100 m, meets a box of the other. Each pair is read twice, as two
-- rigid geometries and as two antenna points, and ordered by how much nearer
-- the hulls come than the antennas.
-------------------------------------------------------------------------------

CREATE TEMP TABLE Close AS
WITH Pairs(MMSI1, MMSI2) AS (
  SELECT DISTINCT b1.MMSI, b2.MMSI
  FROM ShipBoxes b1, ShipBoxes b2
  WHERE b1.MMSI < b2.MMSI AND expandSpace(b1.Box, 100) && b2.Box )
SELECT p.MMSI1, p.MMSI2, s1.Trip AS Trip1, s2.Trip AS Trip2,
  whenTrue(tDwithin(s1.Trip, s2.Trip, 100)) AS Periods
FROM Pairs p JOIN ShipsRigid s1 ON s1.MMSI = p.MMSI1
  JOIN ShipsRigid s2 ON s2.MMSI = p.MMSI2
WHERE eDwithin(s1.Trip, s2.Trip, 100);

SELECT COUNT(*) AS Pairs FROM Close;

SELECT * FROM (
  SELECT c.MMSI1, v1.Name AS Name1, c.MMSI2, v2.Name AS Name2,
    getTimestamp(nearestApproachInstant(atTime(Trip1, Periods), atTime(Trip2, Periods))) AS T,
    round(nearestApproachDistance(atTime(Trip1, Periods), atTime(Trip2, Periods))::numeric, 1) AS HullDist,
    round(nearestApproachDistance(tgeompoint(atTime(Trip1, Periods)),
      tgeompoint(atTime(Trip2, Periods)))::numeric, 1) AS AntennaDist,
    round(ST_Area(s1.Footprint)::numeric) AS Area1, round(ST_Area(s2.Footprint)::numeric) AS Area2
  FROM Close c JOIN ShipShape s1 ON s1.MMSI = c.MMSI1
    JOIN ShipShape s2 ON s2.MMSI = c.MMSI2
    JOIN Vessels v1 ON v1.MMSI = c.MMSI1 JOIN Vessels v2 ON v2.MMSI = c.MMSI2 ) p
ORDER BY AntennaDist - HullDist DESC;

-------------------------------------------------------------------------------
-- The Anholt wind farm: how many vessels come within 10 km of the convex hull
-- of the turbines, and how near they come to its centroid (A) and to that
-- convex hull (B) as hulls, and to the concave hull (C) as antennas. The
-- distance of a hull to C is the one the chapter reports as not supported,
-- C being not convex.
-------------------------------------------------------------------------------

CREATE TEMP TABLE Farm AS
SELECT ST_Centroid(ST_Collect(Geom)) AS A, ST_ConvexHull(ST_Collect(Geom)) AS B,
  ST_ConcaveHull(ST_Collect(Geom), 0.3) AS C
FROM Turbines;

SELECT COUNT(*) AS VesselsWithin10km
FROM ShipsRigid, Farm WHERE eDwithin(tgeompoint(Trip), B, 10000);

SELECT round(MIN(nearestApproachDistance(s.Trip, f.A))::numeric) AS HullToA,
  round(MIN(nearestApproachDistance(s.Trip, f.B))::numeric) AS HullToB,
  round(MIN(nearestApproachDistance(tgeompoint(s.Trip), f.C))::numeric) AS AntennaToC
FROM ShipsRigid s, Farm f WHERE eDwithin(tgeompoint(s.Trip), f.B, 10000);

-------------------------------------------------------------------------------
-- The vessels the text names at the wind farm: the ferry ANHOLT, nearest to A
-- and to B, and the crew-transfer vessels ANHOLT WIND and DJURS WIND, how long
-- their hulls stay inside B
-------------------------------------------------------------------------------

SELECT v.Name, round((s.Trip |=| f.A)::numeric) AS DistA,
  round((s.Trip |=| f.B)::numeric) AS DistB,
  duration(whenTrue(tIntersects(s.Trip, f.B))) AS InsideB
FROM ShipsRigid s JOIN Vessels v USING (MMSI), Farm f
WHERE v.Name IN ('ANHOLT', 'ANHOLT WIND', 'DJURS WIND')
ORDER BY v.Name;
