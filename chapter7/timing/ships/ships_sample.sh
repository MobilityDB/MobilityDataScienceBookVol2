#!/bin/bash
# Write into the tables Sample300 and Sample600 of the PostgreSQL database the ships that the
# reservoir samples of 300 and 600 rows of DuckDB (TABLESAMPLE RESERVOIR (n ROWS) REPEATABLE (1),
# as in the sampled queries of the chapter) draw from the table Ships of ships.duckdb, so that
# the MobilityDB twins pg_m5.sql and pg_m6.sql run over the same ships.
#
#   bash ships_sample.sh
#
# DUCKDB names the DuckDB shell (default `duckdb`), MOBILITYDUCK_EXTENSION the file of the
# MobilityDuck extension when the shell does not carry it, and the libpq variables (PGHOST,
# PGPORT, PGUSER, PGDATABASE) the PostgreSQL database.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
DUCKDB=${DUCKDB:-duckdb}
LOAD=""
[ -n "$MOBILITYDUCK_EXTENSION" ] && LOAD="LOAD spatial; LOAD '$MOBILITYDUCK_EXTENSION';"
for n in 300 600; do
  "$DUCKDB" -unsigned -readonly -csv -noheader "$HERE/ships.duckdb" \
    -c "$LOAD SET threads = 1; SELECT MMSI FROM Ships TABLESAMPLE RESERVOIR ($n ROWS) REPEATABLE (1) ORDER BY MMSI;" \
    > "$HERE/sample$n.csv"
  psql -X -v ON_ERROR_STOP=1 \
    -c "DROP TABLE IF EXISTS Sample$n; CREATE TABLE Sample$n(MMSI bigint PRIMARY KEY);" \
    -c "\\copy Sample$n FROM '$HERE/sample$n.csv' CSV"
  echo "Sample$n: $(wc -l < "$HERE/sample$n.csv") ships"
done
