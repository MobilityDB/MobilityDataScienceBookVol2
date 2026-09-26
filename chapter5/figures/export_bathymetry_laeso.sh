#!/bin/bash
# Export the layers of the figure of the bathymetry around Laeso: the depth
# model over the extent of the figure, the water shallower than 6 m in the
# protected area south of Laeso, and the marine and coastal protected areas.
# Writes to $OUT (default: the working directory); reads the database named by
# the PostgreSQL environment variables and the depth model of $DATA.
set -e
DATA=${DATA:-$PWD/data}
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
gdal_translate -q -projwin 585385 6370350 653011 6301562 \
  "$DATA/ddm/ddm_50m_25832.tif" laeso_depth.tif
ogr2ogr -f GPKG -a_srs EPSG:25832 laeso_shallow.gpkg "$PG" -nln shallow -overwrite -sql \
  "SELECT ST_Union(g) AS geom
   FROM (
     SELECT (ST_DumpAsPolygons(ST_Reclass(ST_Clip(b.Rast, n.Geom), 1,
       '[0-6):1, [6-1000]:0', '8BUI', 0))).geom AS g
     FROM Bathymetry b, NaturalAreas n
     WHERE n.Id = 23 AND ST_Intersects(b.Rast, n.Geom) ) t"
ogr2ogr -f GPKG -a_srs EPSG:25832 laeso_areas.gpkg "$PG" -nln natural_areas -overwrite -sql \
  "SELECT Id AS id, NameEng AS nameeng, Realm AS realm, Geom AS geom
   FROM NaturalAreas WHERE Realm IN ('Marine', 'Coastal')"
gdalinfo laeso_depth.tif | grep 'Size is'
for f in laeso_shallow laeso_areas; do ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
