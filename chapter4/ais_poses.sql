-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- Vessels from AIS data as temporal rigid geometries: the listings of the AIS
-- use case of the chapter, as the chapter prints them and in its order.
--
-- Runs in the AIS database of the book (ais/build.sh of this repository, the
-- day January 20, 2026), which holds the table AISClean, after
-- load_turbines.sql, which adds the table Turbines:
--   psql -d ais -f ais_poses.sql
-- It creates the tables AISCleanPoly, ShipShape, ShipsRigid and ShipBoxes.
-------------------------------------------------------------------------------
\timing on
SET TimeZone = 'UTC';
DROP TABLE IF EXISTS ShipBoxes, ShipsRigid, ShipShape, AISCleanPoly CASCADE;

CREATE TABLE AISCleanPoly AS
WITH InvalidGeom(MMSI) AS (
  SELECT MMSI FROM AISClean
  GROUP BY MMSI
  HAVING COUNT(DISTINCT SizeA) > 1 OR COUNT(DISTINCT SizeB) > 1 OR
    COUNT(DISTINCT SizeC) > 1 OR COUNT(DISTINCT SizeD) > 1 )
SELECT *, ST_X(Geom) AS X, ST_Y(Geom) AS Y
FROM AISClean
WHERE Heading IS NOT NULL AND SizeA IS NOT NULL AND
  SizeB IS NOT NULL AND SizeC IS NOT NULL AND SizeD IS NOT NULL AND
  MMSI NOT IN ( SELECT MMSI FROM InvalidGeom );

CREATE TABLE ShipShape(MMSI, Footprint) AS
SELECT MMSI, ST_MakePolygon(ST_MakeLine(ARRAY[
    ST_Point(-SizeB, -SizeC, 25832),
    ST_Point((3 * SizeA - SizeB) / 4, -SizeC, 25832),
    ST_Point(SizeA, (SizeD - SizeC) / 2, 25832),
    ST_Point((3 * SizeA - SizeB) / 4, SizeD, 25832),
    ST_Point(-SizeB, SizeD, 25832),
    ST_Point(-SizeB, -SizeC, 25832)]))
FROM AISCleanPoly
GROUP BY MMSI, SizeA, SizeB, SizeC, SizeD;

CREATE TABLE ShipsRigid(MMSI, Trip) AS
SELECT a.MMSI, trgeometry(s.Footprint,
  tposeSeq(array_agg(tpose(pose(ST_Point(a.X, a.Y, 25832),
    CASE WHEN a.Heading >= 270
      THEN pi() / 2 - radians(a.Heading) + 2 * pi()
      ELSE pi() / 2 - radians(a.Heading) END), a.T) ORDER BY a.T)))
FROM AISCleanPoly a JOIN ShipShape s USING (MMSI)
GROUP BY a.MMSI, s.Footprint;

-- The two layers of the MOVE plugin of QGIS: every vessel of the day, as a
-- temporal point and as a temporal rigid geometry; the rows go to no file
\o /dev/null
SELECT MMSI, tgeompoint(Trip) FROM ShipsRigid;
SELECT MMSI, Trip FROM ShipsRigid;
\o

SELECT ST_Area(traversedArea(atTime(Trip,
  tstzspan '[2026-01-20 05:42:30, 2026-01-20 05:52]'), true)) AS SweptArea
FROM ShipsRigid WHERE MMSI = 219423000;

SELECT traversedArea(atTime(Trip,
  tstzspan '[2026-01-20 08:10, 2026-01-20 08:37]'), true)
FROM ShipsRigid WHERE MMSI = 636024484;

WITH Zone(Geom) AS (
  SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832) )
SELECT s.MMSI, duration(whenTrue(tIntersects(s.Trip, z.Geom))) AS Inside
FROM ShipsRigid s, Zone z
WHERE eIntersects(s.Trip, z.Geom);

SELECT a.MMSI,
  bodyPointTrajectory(s.Trip, ST_Point(a.SizeA, 0, 25832)) AS BowPath
FROM ShipsRigid s JOIN (SELECT DISTINCT MMSI, SizeA FROM AISCleanPoly) a
  USING (MMSI);

SELECT MMSI, maxValue(degrees(angularSpeed(Trip))) AS MaxRateOfTurn
FROM ShipsRigid
WHERE degrees(angularSpeed(Trip)) ?> 5;

WITH Breakwater(Geom) AS (
  SELECT geometry 'SRID=25832;Point(651337 6058377)' )
SELECT s.MMSI, s.Trip |=| b.Geom AS HullDist,
  tgeompoint(s.Trip) |=| b.Geom AS PointDist,
  (tgeompoint(s.Trip) |=| b.Geom) - (s.Trip |=| b.Geom) AS Overstated
FROM ShipsRigid s, Breakwater b;

WITH Breakwater(Geom) AS (
  SELECT geometry 'SRID=25832;Point(729493 6216766)' )
SELECT s.MMSI, s.Trip |=| b.Geom AS MinDist
FROM ShipsRigid s, Breakwater b
ORDER BY MinDist LIMIT 1;

WITH Farm(Location, Extent) AS (
  SELECT ST_Centroid(ST_Collect(Geom)), ST_ConvexHull(ST_Collect(Geom))
  FROM Turbines )
SELECT s.MMSI, s.Trip |=| f.Location AS LocationDist,
  s.Trip |=| f.Extent AS ExtentDist
FROM ShipsRigid s, Farm f
WHERE eDwithin(s.Trip, f.Extent, 10000);

WITH Motion(MMSI, D) AS (
  SELECT MMSI, abs(degrees(yaw(Trip)) -
    (90 - degrees(azimuth(tgeompoint(Trip)))))
  FROM ShipsRigid )
SELECT MMSI FROM Motion
WHERE atSpanset(D, floatspanset '{(20,340), (380,720)}') IS NOT NULL;

CREATE TABLE ShipBoxes(MMSI, Box) AS
SELECT MMSI, unnest(splitNStboxes(Trip, 50)) FROM ShipsRigid;
CREATE INDEX ShipBoxes_Box_Idx ON ShipBoxes USING gist (Box);

WITH Pairs(MMSI1, MMSI2) AS (
  SELECT DISTINCT b1.MMSI, b2.MMSI
  FROM ShipBoxes b1, ShipBoxes b2
  WHERE b1.MMSI < b2.MMSI AND expandSpace(b1.Box, 300) && b2.Box )
SELECT p.MMSI1, p.MMSI2, startValue(atMin(s1.Trip <-> s2.Trip)) AS Dist
FROM Pairs p JOIN ShipsRigid s1 ON s1.MMSI = p.MMSI1
  JOIN ShipsRigid s2 ON s2.MMSI = p.MMSI2
WHERE eDwithin(s1.Trip, s2.Trip, 300);

WITH Pairs(MMSI1, MMSI2) AS (
  SELECT DISTINCT b1.MMSI, b2.MMSI
  FROM ShipBoxes b1, ShipBoxes b2
  WHERE b1.MMSI < b2.MMSI AND expandSpace(b1.Box, 300) && b2.Box )
SELECT p.MMSI1, p.MMSI2,
  startValue(atMin(s1.Trip <-> s2.Trip)) AS HullDist,
  startValue(atMin(tgeompoint(s1.Trip) <-> tgeompoint(s2.Trip))) AS PointDist
FROM Pairs p JOIN ShipsRigid s1 ON s1.MMSI = p.MMSI1
  JOIN ShipsRigid s2 ON s2.MMSI = p.MMSI2
WHERE eDwithin(s1.Trip, s2.Trip, 300);

WITH AlertBelt(Belt) AS (
  SELECT ST_MakeEnvelope(640730, 6042487, 654100, 6058230, 25832) )
SELECT tCount(atTime(s.Trip, whenTrue(tIntersects(s.Trip, b.Belt)))) AS Present
FROM ShipsRigid s, AlertBelt b
WHERE eIntersects(s.Trip, b.Belt);

WITH Pairs(MMSI1, MMSI2) AS (
  SELECT DISTINCT b1.MMSI, b2.MMSI
  FROM ShipBoxes b1, ShipBoxes b2
  WHERE b1.MMSI < b2.MMSI AND expandSpace(b1.Box, 500) && b2.Box )
SELECT p.MMSI1, p.MMSI2, s1.Trip |=| s2.Trip AS Cpa,
  getTimestamp(nearestApproachInstant(s1.Trip, s2.Trip)) AS Tcpa
FROM Pairs p JOIN ShipsRigid s1 ON s1.MMSI = p.MMSI1
  JOIN ShipsRigid s2 ON s2.MMSI = p.MMSI2
WHERE eDwithin(s1.Trip, s2.Trip, 500);
