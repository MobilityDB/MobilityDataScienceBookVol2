#!/bin/bash
# Build the database of the underwater-noise case study of Chapter 3 for
# January 20, 2026, the AIS day of the book:
# - creates the database $NOISE_DB (default: noise) with MobilityDB;
# - copies into it the tables AISClean and Vessels of the AIS database of the
#   book, $AIS_DB (default: ais), built by ais/build.sh of this repository;
# - defines the functions of tcbuffer_load.sql and loads with tcbuffer_areas()
#   the tables Port, SeaCells and NaturalAreas from the files port.csv,
#   sea_cells.csv.gz and natural_areas.csv.gz of the directory $DATA_DIR, which
#   is read by the database server and is given as an absolute path;
# - builds AISInputTarget from AISClean with tcbuffer_input_ais.sql, and the
#   tables Vessel, VesselPoint and VesselTrip with tcbuffer_trajectories().
#
#   DATA_DIR=/absolute/path/to/data bash tcbuffer_load_ais.sh
#
# The usual libpq variables (PGHOST, PGPORT, PGUSER) select the server.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
NOISE_DB=${NOISE_DB:-noise}
AIS_DB=${AIS_DB:-ais}
: "${DATA_DIR:?set DATA_DIR to the directory of port.csv, sea_cells.csv.gz and natural_areas.csv.gz}"
P="psql -X -v ON_ERROR_STOP=1 -d $NOISE_DB"
createdb "$NOISE_DB"
$P -c "CREATE EXTENSION mobilitydb CASCADE"
pg_dump -d "$AIS_DB" -t aisclean -t vessels | $P -q
$P -f "$HERE/tcbuffer_load.sql"
$P -c "SET tcbuffer.datadir = '${DATA_DIR%/}/'" -c "SELECT tcbuffer_areas()"
$P -f "$HERE/tcbuffer_input_ais.sql"
$P -c "SET TIMEZONE TO 'UTC'" -c "SELECT tcbuffer_trajectories()"
