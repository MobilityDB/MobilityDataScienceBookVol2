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

# Section 8: load the hourly rasters of one field, prepared once in EPSG:25832,
# into <Table>(ValidTime, Rast), one row per tile of each hourly step, valid
# from the step until the next one. Usage:
#   load_field.sh <dir> <table> [<tile> [<YYYYMMDD> [<psql connection options>]]]
# The connection defaults to the PostgreSQL environment variables (PGDATABASE, ...).
# where the files are named <anything>_<YYYYMMDD>T<HH>.tif.
set -e
DIR=$1; TABLE=$2; TILE=${3:-100x100}; DAY=${4:-20260120}
CONN=${5:-""}
PSQL="psql -X -q $CONN -v ON_ERROR_STOP=1"
DAYTS="${DAY:0:4}-${DAY:4:2}-${DAY:6:2}"
$PSQL -c "DROP TABLE IF EXISTS ${TABLE}Load; DROP TABLE IF EXISTS $TABLE;"
first=1
for f in $DIR/*_${DAY}T*.tif; do
  if [ $first = 1 ]; then mode=-c; first=0; else mode=-a; fi
  raster2pgsql -s 25832 -t $TILE -F $mode $f ${TABLE}Load 2> /dev/null | $PSQL
done
$PSQL <<EOF
SET TimeZone = 'UTC';
CREATE TABLE $TABLE AS
SELECT span(t, t + interval '1 hour', true, false) AS ValidTime, Rast
FROM (
  SELECT timestamptz '$DAYTS 00:00:00+00' +
      substring(filename from 'T([0-9]{2})\.tif$')::int * interval '1 hour' AS t,
    rast AS Rast
  FROM ${TABLE}Load ) l;
DROP TABLE ${TABLE}Load;
CREATE INDEX ${TABLE}_Rast_Idx ON $TABLE USING gist (ST_ConvexHull(Rast));
CREATE INDEX ${TABLE}_ValidTime_Idx ON $TABLE USING gist (ValidTime);
ANALYZE $TABLE;
SELECT '$TABLE' AS Field, count(*) AS Tiles, count(DISTINCT ValidTime) AS Steps
FROM $TABLE;
EOF
