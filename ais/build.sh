#!/bin/bash
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
