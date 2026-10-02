#!/bin/bash
# Build the database of chapter 6 in the PostgreSQL database $PGDATABASE (default: semantic)
# from the files that fetch_data.sh downloads into $DATA (default: data/ below the working
# directory): the districts of Delhi imported by osm2pgsql from the OpenStreetMap extract of
# India restricted to the bounding box of Delhi, the Delhi trips with their grid and district
# tessellations, and the Paris tours. The usual libpq variables
# (PGHOST, PGPORT, PGUSER) select the server. The server reads the files of $DATA itself, so it
# must run on the same machine, and the user must be a superuser or a member of the role
# pg_read_server_files. The structure follows ais/build.sh.
#
#   bash build.sh
set -e
DATA=$(cd "${DATA:-$PWD/data}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
export PGDATABASE=${PGDATABASE:-semantic}

psql -q -c "CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE" \
  -c "CREATE EXTENSION IF NOT EXISTS hstore"
osm2pgsql ${PGHOST:+-H "$PGHOST"} ${PGPORT:+-P "$PGPORT"} ${PGUSER:+-U "$PGUSER"} \
  -d "$PGDATABASE" --create --slim -G --hstore --bbox 76.83,28.40,77.35,28.89 \
  "$DATA/india-210101.osm.pbf"
psql -q -v ON_ERROR_STOP=1 -c "SET delhi.datadir = '$DATA/'" -f "$HERE/delhi_load.sql" \
  -c "SELECT delhi_load()"
psql -q -v ON_ERROR_STOP=1 -f "$HERE/paris_tours.sql"
