-- Section 2: PostGIS raster tutorial on Denmark's Depth Model, warped once at
-- preprocessing to EPSG:25832, the reference system of every other table:
--   gdalwarp -t_srs EPSG:25832 -tr 50 50 -tap -r near ddm_50m.dybde.tiff ddm_50m_25832.tif
--   raster2pgsql -s 25832 -t 256x256 -I -C -M -F ddm_50m_25832.tif public.Bathymetry
-- No query below transforms a geometry.
\pset footer off
\timing on

\echo == Q0 tiles and metadata of one tile
SELECT count(*) AS Tiles FROM Bathymetry;
SELECT (ST_MetaData(Rast)).* FROM Bathymetry ORDER BY rid LIMIT 1;

\echo == Q1 depth at a position in the roads of Frederikshavn
SELECT round(ST_Value(Rast, geometry 'SRID=25832;Point(596041 6367497)')::numeric, 2) AS Depth
FROM Bathymetry
WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)');

\echo == Q2 the bathymetry of a protected area
SELECT ST_Width(r) AS Width, ST_Height(r) AS Height,
  round((ST_SummaryStats(r)).count / 400.0, 1) AS AreaKm2
FROM (
  SELECT ST_Union(ST_Clip(b.Rast, n.Geom)) AS r
  FROM Bathymetry b, NaturalAreas n
  WHERE n.Id = 23 AND ST_Intersects(b.Rast, n.Geom)) t;

\echo == Q3 depth statistics per protected area around Laeso
SELECT n.NameEng, round((s).min::numeric, 1) AS MinDepth,
  round((s).mean::numeric, 1) AS MeanDepth, round((s).max::numeric, 1) AS MaxDepth
FROM (
  SELECT n.Id, ST_SummaryStatsAgg(ST_Clip(b.Rast, n.Geom), 1, true) AS s
  FROM Bathymetry b, NaturalAreas n
  WHERE n.Id IN (4, 6, 23, 32, 264) AND ST_Intersects(b.Rast, n.Geom)
  GROUP BY n.Id) t JOIN NaturalAreas n ON n.Id = t.Id
ORDER BY MeanDepth;

\echo == Q4 the water shallower than 6 m in the protected area south of Laeso
SELECT round((ST_Area(ST_Union(g)) / 1e6)::numeric, 1) AS ShallowKm2
FROM (
  SELECT (ST_DumpAsPolygons(ST_Reclass(ST_Clip(b.Rast, n.Geom),
    1, '[0-6):1, [6-1000]:0', '8BUI', 0))).geom AS g
  FROM Bathymetry b, NaturalAreas n
  WHERE n.Id = 23 AND ST_Intersects(b.Rast, n.Geom)) t;

\echo == Q5 resampling of the tile under Frederikshavn roads
SELECT ST_Width(r) AS Width, ST_Height(r) AS Height, ST_ScaleX(r) AS ScaleX
FROM (
  SELECT ST_Rescale(Rast, 500) AS r
  FROM Bathymetry
  WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)')) t;

\echo == Q6 map algebra: pixels with less than 17 m of water in the same tile
SELECT (ST_SummaryStats(r)).sum AS ShallowPixels, (ST_SummaryStats(r)).count AS SeaPixels
FROM (
  SELECT ST_MapAlgebra(Rast, 1, '8BUI', 'CASE WHEN [rast] < 17 THEN 1 ELSE 0 END') AS r
  FROM Bathymetry
  WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)')) t;
