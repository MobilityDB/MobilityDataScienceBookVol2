-- Raster Data in PostGIS: the loaded bathymetry and the basic queries of the
-- tutorial. Every table is in EPSG:25832, so no query transforms a geometry.
-- Each listing of the chapter is preceded by its printed answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == tiles of the bathymetry and size of the table (886 tiles, 173 MB)
SELECT COUNT(*) AS Tiles,
  pg_size_pretty(pg_total_relation_size('bathymetry')) AS Size
FROM Bathymetry;

\echo == Listing: metadata of a tile
/* upperleftx | upperlefty | width | height | scalex | scaley | skewx | skewy |
   550300     | 6466200    | 256   | 256    | 50     | -50    | 0     | 0     |
   srid  | numbands
   25832 | 1 */
SELECT (ST_MetaData(Rast)).* FROM Bathymetry ORDER BY rid LIMIT 1;

\echo == Query: depth at a position in the roads of Frederikshavn (8.88)
SELECT ST_Value(Rast, geometry 'SRID=25832;Point(596041 6367497)') AS Depth
FROM Bathymetry
WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)');

\echo == Query: resample the tile under the roads of Frederikshavn to pixels of 500 m (26 | 500)
SELECT ST_Width(r) AS Width, ST_ScaleX(r) AS ScaleX
FROM (
  SELECT ST_Rescale(Rast, 500) AS r
  FROM Bathymetry
  WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)') ) t;
