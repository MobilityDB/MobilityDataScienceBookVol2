-- Map Algebra: local, binary, focal, and zonal operations, and the intersection
-- of a trajectory with a raster, first on the raster Depth of 4 x 4 pixels and
-- then on the bathymetry and the hourly wave height. Every table is in
-- EPSG:25832, so no query transforms a geometry. Each listing of the chapter is
-- preceded by its printed answer; where the chapter states that its results are
-- rounded, the query prints them unrounded. The tables Seabed, SeabedMean, and
-- BathymetryMin100 are used by the case study and the figures.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Listing: the raster Depth of 4 x 4 pixels of 100 m
DROP TABLE IF EXISTS Depth;
CREATE TABLE Depth(Rast raster);
INSERT INTO Depth
SELECT ST_SetValues(ST_AddBand(
  ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
  '32BF'::text, 0, -9999), 1, 1, 1,
  ARRAY[[12,14,16,18], [11,13,15,17], [9,10,12,14], [6,8,9,11]]::float[][]);
SELECT ST_DumpValues(Rast, 1) FROM Depth;

\echo == Listing: local operation, the clearance under a draught of 10 m
-- {{2,4,6,8},{1,3,5,7},{-1,0,2,4},{-4,-2,-1,1}}
SELECT ST_DumpValues(ST_MapAlgebra(Rast, 1, NULL, '[rast] - 10'), 1)
FROM Depth;

\echo == Listing: reclassification into three depth classes
-- {{2,3,3,3},{2,2,3,3},{1,2,2,3},{1,1,1,2}}
SELECT ST_DumpValues(ST_Reclass(Rast, 1, '[0-10):1, [10-14):2, [14-100]:3',
  '8BUI', 0), 1)
FROM Depth;

\echo == Query: pixels of the tile under the roads of Frederikshavn with less than 17 m of water
-- 32577 | 51887
SELECT (ST_SummaryStats(r)).sum AS ShallowPixels,
  (ST_SummaryStats(r)).count AS SeaPixels
FROM (
  SELECT ST_MapAlgebra(Rast, 1, '8BUI',
    'CASE WHEN [rast] < 17 THEN 1 ELSE 0 END') AS r
  FROM Bathymetry
  WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)') ) t;

\echo == Query: area of the water shallower than 6 m in the protected area south of Laeso
-- 109.5 (rounded)
SELECT ST_Area(ST_Union(g)) / 1e6 AS ShallowKm2
FROM (
  SELECT (ST_DumpAsPolygons(ST_Reclass(ST_Clip(b.Rast, n.Geom), 1,
    '[0-6):1, [6-1000]:0', '8BUI', 0))).geom AS g
  FROM Bathymetry b, NaturalAreas n
  WHERE n.Id = 23 AND ST_Intersects(b.Rast, n.Geom) ) t;
\echo == area of the protected area south of Laeso (365.2 km2, all of it water)
SELECT round((ST_Area(Geom) / 1e6)::numeric, 1) AS AreaKm2 FROM NaturalAreas WHERE Id = 23;

-- Listing: the normalized difference vegetation index. It needs the tables Red
-- and NearInfrared of a Landsat 8 scene, which the chapter does not use; the
-- last exercise of the chapter loads such a scene.
--   CREATE TABLE NDVI AS
--   SELECT ST_MapAlgebra(r.Rast, 1, n.Rast, 1,
--     'CASE WHEN [rast1] + [rast2] = 0 THEN NULL
--      ELSE ([rast2] - [rast1]) / ([rast1] + [rast2]) END', '32BF') AS Rast
--   FROM Red r JOIN NearInfrared n ON
--     ST_UpperLeftX(r.Rast) = ST_UpperLeftX(n.Rast) AND
--     ST_UpperLeftY(r.Rast) = ST_UpperLeftY(n.Rast);

\echo == Query: how did the wave height change between 12:00 and 23:00
-- 0.42 | -0.51 | 0.98 | 282134
SELECT round((s).mean::numeric, 2) AS Mean, round((s).min::numeric, 2) AS Min,
  round((s).max::numeric, 2) AS Max, (s).count AS Pixels
FROM (
  SELECT ST_SummaryStatsAgg(ST_MapAlgebra(a.Rast, 1, b.Rast, 1,
    '[rast2] - [rast1]'), 1, true) AS s
  FROM WaveHeight a JOIN WaveHeight b
    ON ST_UpperLeftX(a.Rast) = ST_UpperLeftX(b.Rast) AND
       ST_UpperLeftY(a.Rast) = ST_UpperLeftY(b.Rast)
  WHERE lower(a.ValidTime) = '2026-01-20 12:00+00' AND
    lower(b.ValidTime) = '2026-01-20 23:00+00' ) t;

\echo == Listing: the bathymetry and the wave height are not aligned
-- NOTICE: The rasters have different scales on the X axis
-- f
SET client_min_messages = notice;
SELECT ST_SameAlignment(b.Rast, w.Rast)
FROM Bathymetry b, WaveHeight w
WHERE b.rid = 27 AND ST_Intersects(b.Rast, w.Rast)
LIMIT 1;
SET client_min_messages = warning;

\echo == Query: water less than 20 m deep under waves of at least 1 m at 23:00
/* Class | Km2
   0     | 95600.2
   1     |  1149.8
   2     |     0.3 */
DROP TABLE IF EXISTS ShallowRough;
CREATE TABLE ShallowRough AS
WITH Waves AS (
  SELECT ST_Union(Rast) AS Rast
  FROM WaveHeight
  WHERE lower(ValidTime) = '2026-01-20 23:00+00' )
SELECT b.rid, ST_MapAlgebra(b.Rast, 1,
  ST_Resample(ST_Clip(w.Rast, ST_Envelope(b.Rast)), b.Rast), 1,
  'CASE WHEN [rast1] >= 20 THEN 0 WHEN [rast2] >= 1.5 THEN 2
   WHEN [rast2] >= 1 THEN 1 ELSE 0 END', '8BUI', 'FIRST') AS Rast
FROM Bathymetry b, Waves w
WHERE ST_Intersects(b.Rast, w.Rast);
SELECT v.value AS Class, round(sum(v.count) * 0.0025, 1) AS Km2
FROM ShallowRough, ST_ValueCount(Rast) v
GROUP BY v.value
ORDER BY v.value;
\echo == water less than 20 m deep in the whole model (31,346.5 km2)
SELECT round(sum((ST_SummaryStats(ST_Reclass(Rast, 1, '[0-20):1', '8BUI', 0))).count)
  * 0.0025, 1) AS Shallow20Km2
FROM Bathymetry;

\echo == Listing: focal operation, mean of the 3 x 3 window
/* {{12.5,13.5,15.5,16.5},{11.5,12.44,14.33,15.33},
    {9.5,10.33,12.11,13},{8.25,9,10.67,11.5}} (rounded to two decimals) */
SELECT ST_DumpValues(ST_MapAlgebra(Rast, 1,
  'ST_Mean4ma(double precision[][][], integer[][], text[])'::regprocedure,
  '32BF', 'FIRST', NULL, 1, 1), 1)
FROM Depth;

\echo == Listing: the seabed of Laeso Trindel og Toenneberg Banke
DROP TABLE IF EXISTS Seabed;
CREATE TABLE Seabed AS
SELECT n.Id, n.Geom, ST_MapAlgebra(ST_Union(b.Rast), 1, NULL, '-[rast]') AS Rast
FROM Bathymetry b, NaturalAreas n
WHERE n.Id = 22 AND ST_Intersects(b.Rast, n.Geom)
GROUP BY n.Id, n.Geom;
\echo == size of the assembled raster (256 x 512) and of the area (87.3 km2)
SELECT ST_Width(Rast) AS Width, ST_Height(Rast) AS Height,
  round((ST_Area(Geom) / 1e6)::numeric, 1) AS AreaKm2
FROM Seabed;

\echo == Query: slope and ruggedness of the seabed in the reef area
-- 0.50 | 5.29 | 0.36 | 3.53
SELECT round((s).mean::numeric, 2) AS MeanSlope,
  round((s).max::numeric, 2) AS MaxSlope,
  round((r).mean::numeric, 2) AS MeanTRI, round((r).max::numeric, 2) AS MaxTRI
FROM (
  SELECT ST_SummaryStats(ST_Clip(ST_Slope(Rast, 1, '32BF', 'DEGREES', 1.0),
    Geom)) AS s,
    ST_SummaryStats(ST_Clip(ST_TRI(Rast, 1, '32BF'), Geom)) AS r
  FROM Seabed ) t;

\echo == Query: banks and hollows of the reef area, window of 150 m and of 1 km
/* Class | Km2
   1     |  0.12
   2     | 86.89
   3     |  0.28 */
SELECT v.value AS Class, round(v.count * 0.0025, 2) AS Km2
FROM Seabed s, ST_ValueCount(ST_Reclass(ST_Clip(ST_TPI(s.Rast, 1, '32BF'),
  s.Geom), 1, '[-100--1):1, [-1-1]:2, (1-100]:3', '8BUI', 0)) v
ORDER BY v.value;
/* Class | Km2
   1     | 10.04
   2     | 65.30
   3     | 11.94 */
DROP TABLE IF EXISTS SeabedMean;
CREATE TABLE SeabedMean AS
SELECT Id, ST_MapAlgebra(Rast, 1,
  'ST_Mean4ma(double precision[][][], integer[][], text[])'::regprocedure,
  '32BF', 'FIRST', NULL, 10, 10) AS Rast
FROM Seabed;
SELECT v.value AS Class, round(v.count * 0.0025, 2) AS Km2
FROM Seabed s JOIN SeabedMean m USING (Id),
  ST_ValueCount(ST_Reclass(ST_Clip(ST_MapAlgebra(s.Rast, 1, m.Rast, 1,
    '[rast1] - [rast2]'), s.Geom), 1, '[-100--1):1, [-1-1]:2, (1-100]:3',
    '8BUI', 0)) v
ORDER BY v.value;

\echo == Listing: shallowest water within 100 m, on the tiles crossed by the vessel (51 tiles)
DROP TABLE IF EXISTS BathymetryMin100;
CREATE TABLE BathymetryMin100 AS
WITH Tiles AS (
  SELECT DISTINCT b.rid, b.Rast
  FROM Ships s, Bathymetry b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) ),
Neighbors AS (
  SELECT t.rid, t.Rast, ST_Union(n.Rast) AS Nbr
  FROM Tiles t, Bathymetry n
  WHERE ST_Intersects(n.Rast, ST_Expand(ST_Envelope(t.Rast), 100))
  GROUP BY t.rid, t.Rast )
SELECT rid, ST_MapAlgebra(ARRAY[ROW(Nbr, 1)]::rastbandarg[],
  'ST_Min4ma(double precision[][][], integer[][], text[])'::regprocedure,
  '32BF', 'CUSTOM', Rast, 2, 2) AS Rast
FROM Neighbors;
SELECT count(*) AS Tiles FROM BathymetryMin100;

\echo == Listing: zonal operation with the zones of a raster
/* Zone | Pixels | MeanDepth
   1    |      4 |      8.00
   2    |      6 |     11.50
   3    |      6 |     15.67 */
SELECT z.val AS Zone, count(*) AS Pixels, round(avg(d.val)::numeric, 2) AS MeanDepth
FROM Depth r
  CROSS JOIN LATERAL ST_PixelAsPoints(ST_Reclass(r.Rast, 1,
    '[0-10):1, [10-14):2, [14-100]:3', '8BUI', 0)) z
  JOIN LATERAL ST_PixelAsPoints(r.Rast) d USING (x, y)
GROUP BY z.val
ORDER BY z.val;

\echo == Listing: zonal operation with the regions of the zones
/* Zone | MeanDepth
   1    |      8.00
   2    |     11.00
   2    |     11.60
   3    |     15.67 */
SELECT (g).val AS Zone,
  round((ST_SummaryStats(ST_Clip(r.Rast, (g).geom))).mean::numeric, 2)
    AS MeanDepth
FROM Depth r, ST_DumpAsPolygons(ST_Reclass(r.Rast, 1,
  '[0-10):1, [10-14):2, [14-100]:3', '8BUI', 0)) g
ORDER BY 1, 2;

\echo == Query: depth statistics of the protected areas around Laeso
/* NameEng                   | MinDepth | MeanDepth | MaxDepth   (rounded)
   Waters around Læsø        | 0.0      | 6.1       | 43.8
   Læsø, sydlige del         | 4.3      | 7.7       | 25.7
   Ålborg Bugt, østlige del  | 0.0      | 9.3       | 24.1
   Nordvestlige Kattegat     | 0.0      | 10.1      | 72.5
   Skagens Gren og Skagerrak | 0.0      | 92.4      | 215.7 */
SELECT n.NameEng, (s).min AS MinDepth, (s).mean AS MeanDepth,
  (s).max AS MaxDepth
FROM (
  SELECT n.Id, ST_SummaryStatsAgg(ST_Clip(b.Rast, n.Geom), 1, true) AS s
  FROM Bathymetry b, NaturalAreas n
  WHERE n.Id IN (4, 6, 23, 32, 264) AND ST_Intersects(b.Rast, n.Geom)
  GROUP BY n.Id ) t JOIN NaturalAreas n ON n.Id = t.Id
ORDER BY MeanDepth;

\echo == Query: area of three protected areas around Laeso in each class of depth
/* NameEng                         | DepthClass | Km2
   Læsø Trindel og Tønneberg Banke |          1 |   3.0
   Læsø Trindel og Tønneberg Banke |          2 |  60.6
   Læsø Trindel og Tønneberg Banke |          3 |  23.7
   Læsø, sydlige del               |          1 | 312.6
   Læsø, sydlige del               |          2 |  51.7
   Læsø, sydlige del               |          3 |   0.9
   Waters around Læsø              |          1 | 884.6
   Waters around Læsø              |          2 |  96.8
   Waters around Læsø              |          3 |  12.6 */
SELECT n.NameEng, v.value AS DepthClass, round(sum(v.count) * 0.0025, 1) AS Km2
FROM Bathymetry b, NaturalAreas n,
  ST_ValueCount(ST_Reclass(ST_Clip(b.Rast, n.Geom), 1,
    '[0-10):1, [10-20):2, [20-1000]:3', '8BUI', 0)) v
WHERE n.Id IN (4, 22, 23) AND ST_Intersects(b.Rast, n.Geom)
GROUP BY n.NameEng, v.value
ORDER BY n.NameEng, v.value;

\echo == Query: stretches of the path of the vessel over water less than 20 m deep
-- 13 | 3287.0
SELECT count(*) AS Stretches, round(sum(ST_Length(geom))::numeric, 1) AS Meters
FROM (
  SELECT (ST_Dump(ST_LineMerge(ST_Union((gv).geom)))).geom
  FROM (
    SELECT ST_Intersection(trajectory(s.Trip),
      ST_Reclass(b.Rast, 1, '[0-20):1', '8BUI', 0)) AS gv
    FROM Ships s, Bathymetry b
    WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) ) t
  WHERE ST_Length((gv).geom) > 0 ) u;

\echo == Listing: a line with measures loses them in the intersection
/* Piece                                     | Depth
   LINESTRING(600020 6400150,600100 6400150) |     9
   LINESTRING(600100 6400150,600200 6400150) |    10
   LINESTRING(600200 6400150,600300 6400150) |    12
   LINESTRING(600300 6400150,600380 6400150) |    14 */
SELECT ST_AsText((gv).geom) AS Piece, (gv).val AS Depth
FROM (
  SELECT ST_Intersection(geometry 'SRID=25832;LINESTRING M(600020 6400150 0,
    600380 6400150 360)', Rast) AS gv
  FROM Depth ) t;
