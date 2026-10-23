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

# Export the layers of the figure of the depth under the vessel 273277840
# between 01:27:30 and 01:29:10 UTC: the depth model and its pixels around that
# stretch, the trip, its reports, and the stretches over water less than 20 m
# deep. Writes to $OUT (default: the working directory); reads the database
# named by the PostgreSQL environment variables and the depth model of $DATA.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
W="tstzspan '[2026-01-20 01:27:30+00, 2026-01-20 01:29:10+00]'"
export PGTZ=UTC
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING vessel_trip.gpkg "$PG" -nln trip -overwrite -sql \
  "SELECT trajectory(atTime(Trip, $W)) AS geom FROM Ships WHERE MMSI = 273277840"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POINT vessel_reports.gpkg "$PG" -nln reports -overwrite -sql \
  "SELECT to_char(T, 'HH24:MI:SS') AS label, Geom AS geom FROM AISClean
   WHERE MMSI = 273277840 AND T BETWEEN '2026-01-20 01:27:30' AND '2026-01-20 01:29:10'"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING vessel_shallow.gpkg "$PG" -nln shallow -overwrite -sql \
  "WITH D AS (SELECT s.Trip, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
     FROM Ships s, Bathymetry b
     WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip))
     GROUP BY s.Trip)
   SELECT (ST_Dump(trajectory(atTime(atTime(Trip, $W), whenTrue(Depth #< 20))))).geom AS geom FROM D"
ogr2ogr -f GPKG -a_srs EPSG:25832 vessel_pixels.gpkg "$PG" -nln pixels -overwrite -sql \
  "WITH E AS (
     SELECT ST_Expand(ST_Envelope(trajectory(atTime(Trip, $W))), 250) AS g
     FROM Ships WHERE MMSI = 273277840 )
   SELECT (p).val AS depth, (p).geom AS geom
   FROM (
     SELECT ST_PixelAsPolygons(ST_Union(ST_Clip(b.Rast, e.g))) AS p
     FROM Bathymetry b, E e
     WHERE ST_Intersects(b.Rast, e.g)
     GROUP BY e.g ) t"
read XMIN YMIN XMAX YMAX < <(psql -X -At -F ' ' -c \
  "SELECT ST_XMin(b) - 250, ST_YMin(b) - 250, ST_XMax(b) + 250, ST_YMax(b) + 250
   FROM (SELECT ST_Envelope(trajectory(atTime(Trip, $W))) AS b
     FROM Ships WHERE MMSI = 273277840) t")
gdal_translate -q -projwin $XMIN $YMAX $XMAX $YMIN \
  "${DATA:-$PWD/data}/ddm/ddm_50m_25832.tif" vessel_depth.tif
for f in vessel_trip vessel_reports vessel_shallow vessel_pixels; do
  ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
gdalinfo vessel_depth.tif | grep 'Size is'
