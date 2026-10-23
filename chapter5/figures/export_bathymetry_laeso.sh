#!/bin/bash
#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

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
