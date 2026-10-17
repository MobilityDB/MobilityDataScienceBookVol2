-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- The numbers the text of the AIS use case quotes and no listing prints
--
-- Reads the tables of the AIS use case (Ships, ShipShape, AISInputFilteredPoly,
-- built by ais_poses.sql) and the turbines of the Anholt wind farm (WindTurbine,
-- built by load_turbines.sql). Run against the AIS database:
--   psql -d ais -f text_numbers.sql
--
-- Last run against PostgreSQL 18.6, PostGIS 3.6.4, MobilityDB 1.4.
-------------------------------------------------------------------------------

\timing on
SET TimeZone = 'Europe/Copenhagen';

-------------------------------------------------------------------------------
-- Close encounters: the vessels within 100 m of each other, as the book's query
-- finds them. The bounding-box prefilter discards only the pairs whose boxes,
-- expanded by 100 m, never meet, so the pairs are those of the book's query.
-- Each pair is read twice, as two rigid geometries and as two antenna points,
-- and ordered by how much nearer the hulls come than the antennas.
-------------------------------------------------------------------------------

CREATE TEMP TABLE Close AS
SELECT s1.MMSI AS MMSI1, s2.MMSI AS MMSI2, s1.Trip AS Trip1, s2.Trip AS Trip2,
  whenTrue(tDwithin(s1.Trip, s2.Trip, 100)) AS Periods
FROM Ships s1 JOIN Ships s2 ON s1.MMSI < s2.MMSI
WHERE expandSpace(stbox(s1.Trip), 100) && stbox(s2.Trip)
  AND eDwithin(s1.Trip, s2.Trip, 100);

SELECT count(*) AS Pairs FROM Close;

SELECT * FROM (
  SELECT c.MMSI1, (SELECT max(Name) FROM AISInputFilteredPoly WHERE MMSI = c.MMSI1) AS Name1,
    c.MMSI2, (SELECT max(Name) FROM AISInputFilteredPoly WHERE MMSI = c.MMSI2) AS Name2,
    getTimestamp(nearestApproachInstant(atTime(Trip1, Periods), atTime(Trip2, Periods))) AS T,
    round(nearestApproachDistance(atTime(Trip1, Periods), atTime(Trip2, Periods))::numeric, 1) AS HullDist,
    round(nearestApproachDistance(tgeompoint(atTime(Trip1, Periods)),
      tgeompoint(atTime(Trip2, Periods)))::numeric, 1) AS AntennaDist,
    round(ST_Area(s1.Footprint)::numeric) AS Area1, round(ST_Area(s2.Footprint)::numeric) AS Area2
  FROM Close c JOIN ShipShape s1 ON s1.MMSI = c.MMSI1
    JOIN ShipShape s2 ON s2.MMSI = c.MMSI2 ) p
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
FROM WindTurbine;

SELECT count(*) AS VesselsWithin10km
FROM Ships, Farm WHERE eDwithin(tgeompoint(Trip), B, 10000);

SELECT round(min(nearestApproachDistance(s.Trip, f.A))::numeric) AS HullToA,
  round(min(nearestApproachDistance(s.Trip, f.B))::numeric) AS HullToB,
  round(min(nearestApproachDistance(tgeompoint(s.Trip), f.C))::numeric) AS AntennaToC
FROM Ships s, Farm f WHERE eDwithin(tgeompoint(s.Trip), f.B, 10000);
