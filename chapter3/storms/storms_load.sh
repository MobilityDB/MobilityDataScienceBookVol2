#!/bin/sh
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

# -----------------------------------------------------------------------------
# Load the shapefiles downloaded by storms_download.sh into PostgreSQL, one
# table per kind of shapefile, which gathers the files of all the storms of
# the season: Points<year>, Lines<year>, Radii<year> and Swath<year>. The
# attributes of the tables are those of the shapefiles.
#
# The coordinates of the shapefiles are longitudes and latitudes in degrees.
# Their projection files refer to a sphere of radius 6,371.2 km rather than to
# the WGS 84 ellipsoid; at the scale of 1:2,000,000 for which NOAA intends the
# data the difference is negligible, and the geometries are loaded in SRID 4326
# (option -s 4326 of shp2pgsql).
#
# Usage: storms_load.sh <year> <database> [<basin>] [<directory>]
#   The connection parameters other than the database are read from the
#   environment variables of psql (PGHOST, PGPORT, PGUSER).
# -----------------------------------------------------------------------------
set -eu

YEAR=${1:?usage: storms_load.sh <year> <database> [<basin>] [<directory>]}
DB=${2:?usage: storms_load.sh <year> <database> [<basin>] [<directory>]}
BASIN=${3:-al}
DIR=${4:-./data/${BASIN}${YEAR}}

for kind in pts:Points lin:Lines radii:Radii windswath:Swath; do
  suffix=${kind%%:*}
  table=${kind#*:}${YEAR}
  # The first shapefile creates the table (-c), the others are appended to it
  # (-a)
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -c "DROP TABLE IF EXISTS $table"
  mode=-c
  for shp in "$DIR"/shape/*_${suffix}.shp; do
    shp2pgsql -s 4326 -D $mode "$shp" "$table"
    mode=-a
  done | psql -q -v ON_ERROR_STOP=1 -d "$DB"
  echo "$table: $(psql -At -d "$DB" -c "SELECT count(*) FROM $table") rows"
done
