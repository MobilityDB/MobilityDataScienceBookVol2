#!/bin/bash
# Export the layers of the figure of the depth under the vessel 273277840
# between 01:27:30 and 01:29:10 UTC: the pixels of the bathymetry around that
# stretch with their depth, the trip, its reports, and the stretches over water
# less than 20 m deep. Writes to $OUT (default: the working directory); reads
# the database named by the PostgreSQL environment variables.
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
for f in vessel_trip vessel_reports vessel_shallow vessel_pixels; do
  ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
