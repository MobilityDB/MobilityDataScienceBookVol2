#!/bin/bash
# Export the layers of the Section 3 close-up: the trip, its reports, and the
# stretches over water less than 20 m deep, between 01:27:30 and 01:29:10 UTC.
set -e
cd "${OUT:-$PWD}"
PG="PG:${PGCONN:-dbname=tess}"
W="tstzspan '[2026-01-20 01:27:30+00, 2026-01-20 01:29:10+00]'"
export PGTZ=UTC
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING sec3_trip.gpkg "$PG" -nln trip -overwrite -sql \
  "SELECT trajectory(atTime(Trip, $W)) AS geom FROM Ships WHERE MMSI = 273277840"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POINT sec3_reports.gpkg "$PG" -nln reports -overwrite -sql \
  "SELECT to_char(T, 'HH24:MI:SS') AS label, Geom AS geom FROM AISClean
   WHERE MMSI = 273277840 AND T BETWEEN '2026-01-20 01:27:30' AND '2026-01-20 01:29:10'"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING sec3_shallow.gpkg "$PG" -nln shallow -overwrite -sql \
  "WITH D AS (SELECT s.Trip, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
     FROM Ships s, Bathymetry b
     WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip))
     GROUP BY s.Trip)
   SELECT (ST_Dump(trajectory(atTime(atTime(Trip, $W), whenTrue(Depth #< 20))))).geom AS geom FROM D"
psql -X -At -c \
  "SELECT ST_XMin(b)-250, ST_YMin(b)-250, ST_XMax(b)+250, ST_YMax(b)+250
   FROM (SELECT ST_Envelope(trajectory(atTime(Trip, $W))) AS b FROM Ships WHERE MMSI = 273277840) t" > sec3_extent.txt
cat sec3_extent.txt
read XMIN YMIN XMAX YMAX < <(tr '|' ' ' < sec3_extent.txt)
gdal_translate -q -projwin $XMIN $YMAX $XMAX $YMIN ${DATA:-$PWD/data}/ddm/ddm_50m_25832.tif sec3_depth.tif
gdalinfo sec3_depth.tif | grep 'Size is'
for f in sec3_trip sec3_reports sec3_shallow; do ogrinfo -so $f.gpkg ${f#sec3_} | grep 'Feature Count'; done
