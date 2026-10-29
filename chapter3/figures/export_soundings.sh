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

# The layers of the figure of the two multibeam survey lines off Rostock, into
# $OUT (default: the working directory), from the tables of
# ../soundings/load_soundings.sql: the mean topography of the soundings of both
# lines in cells of 1 m, the trips of the survey vessel, the square of 10 m
# where the lines cross, and the soundings of each survey within 1.5 m of the
# center of the square; and the files of the soundings per ping in the square,
# which soundings_per_ping.tex reads.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
export PGTZ=UTC
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POINT soundings_cells.gpkg "$PG" -nln cells -overwrite -sql \
  "SELECT ST_Point(floor(getX(p.Point)) + 0.5, floor(getY(p.Point)) + 0.5, 25832) AS geom,
     AVG(getZ(p.Point)) AS z
   FROM Swaths, points(Swath) p
   GROUP BY floor(getX(p.Point)), floor(getY(p.Point))"
gdal_rasterize -q -a z -tr 1 1 -tap -a_nodata -9999 -ot Float32 \
  soundings_cells.gpkg soundings_topo.tif
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING soundings_trips.gpkg "$PG" -nln trips -overwrite -sql \
  "SELECT left(Line, 8) AS day, trajectory(Trip) AS geom FROM Tracks"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POLYGON soundings_square.gpkg "$PG" -nln square -overwrite -sql \
  "SELECT ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832) AS geom"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POINT soundings_points.gpkg "$PG" -nln points -overwrite -sql \
  "SELECT left(Line, 8) AS day, ST_Point(getX(p.Point), getY(p.Point), 25832) AS geom
   FROM Swaths, points(atGeometry(Swath,
     ST_MakeEnvelope(702993.5, 6008575.5, 702996.5, 6008578.5, 25832))) p"
# The soundings that each ping put into the square, from the aggregate
# tnpoints, as the seconds since the first ping of the line that sounded the
# square and the number of soundings, one file per survey.
for day in 20190514 20191022; do
  psql -X -q -c "\\copy (
    WITH n AS (
      SELECT unnest(instants(tnpoints(atGeometry(Swath,
        ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832))))) AS i
      FROM Swaths WHERE left(Line, 8) = '$day' )
    SELECT round(extract(epoch FROM getTimestamp(i) -
        MIN(getTimestamp(i)) OVER ())::numeric, 3) AS s, getValue(i) AS n
    FROM n ORDER BY 1) TO 'soundings_per_ping_$day.csv' WITH (FORMAT csv, HEADER true)"
done
wc -l soundings_per_ping_*.csv
for f in soundings_cells soundings_trips soundings_square soundings_points; do
  ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
gdalinfo soundings_topo.tif | grep 'Size is'
