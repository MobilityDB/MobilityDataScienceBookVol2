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

# Export the layers of the figure of the seabed of Laeso Trindel og Toenneberg
# Banke: its hillshade with a vertical exaggeration of 20, its slope, its
# topographic position with a window of 1 km (tables Seabed and SeabedMean of
# map_algebra.sql), and the outline of the area. Writes to $OUT (default: the
# working directory); reads the database named by the PostgreSQL environment
# variables.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
PSQL="psql -X -At -q -v ON_ERROR_STOP=1"
GTIFF="SET postgis.gdal_enabled_drivers = 'GTiff';"
$PSQL -c "$GTIFF" -c "SELECT encode(ST_AsGDALRaster(ST_HillShade(Rast, 1, '32BF',
  315, 45, 255, 0.05), 'GTiff'), 'hex') FROM Seabed" | xxd -r -p > seabed_hillshade.tif
$PSQL -c "$GTIFF" -c "SELECT encode(ST_AsGDALRaster(ST_Slope(Rast, 1, '32BF',
  'DEGREES', 1.0), 'GTiff'), 'hex') FROM Seabed" | xxd -r -p > seabed_slope.tif
$PSQL -c "$GTIFF" -c "SELECT encode(ST_AsGDALRaster(ST_Reclass(ST_MapAlgebra(s.Rast, 1,
  m.Rast, 1, '[rast1] - [rast2]'), 1, '[-100--1):1, [-1-1]:2, (1-100]:3', '8BUI', 0),
  'GTiff'), 'hex') FROM Seabed s JOIN SeabedMean m USING (Id)" | xxd -r -p > seabed_tpi.tif
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt MULTIPOLYGON seabed_area.gpkg "$PG" -nln area \
  -overwrite -sql "SELECT ST_Multi(Geom) AS geom FROM NaturalAreas WHERE Id = 22"
for f in seabed_hillshade seabed_slope seabed_tpi; do gdalinfo $f.tif | grep 'Size is'; done
