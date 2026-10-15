#!/bin/sh
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
