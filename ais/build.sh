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

# Build the AIS database of the book in the PostgreSQL database $PGDATABASE (default: ais) from
# the archives that fetch_data.sh downloads into $DATA (default: data/ below the working
# directory): AISInput, AISClean, Segments, Vessels and Ships.
#
#   bash build.sh [day | month]
#
# day (the default) builds January 20, 2026; month builds January 2026. The usual libpq
# variables (PGHOST, PGPORT, PGUSER) select the server.
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
export PGDATABASE=${PGDATABASE:-ais}

case ${1:-day} in
  day) LO=2026-01-20; HI=2026-01-21; DAYS="2026-01-20" ;;
  month) LO=2026-01-01; HI=2026-02-01; DAYS=$(seq -f "2026-01-%02g" 1 31) ;;
  *) echo "unknown period: $1"; exit 1 ;;
esac

psql -q -f "$HERE/ais_load.sql"
for d in $DAYS; do
  echo "loading: aisdk-$d"
  unzip -p "$DATA/ais/aisdk-$d.zip" | PGOPTIONS='-c datestyle=ISO,DMY' \
    psql -c "\copy AISInput FROM STDIN CSV HEADER"
done
psql -v lo="$LO" -v hi="$HI" -v mid_csv="$DATA/itu_mid.csv" -f "$HERE/ais_clean.sql"
psql -f "$HERE/ais_segments.sql"
psql -f "$HERE/ais_ships.sql"
