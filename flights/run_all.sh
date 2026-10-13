#!/bin/bash
# Run the queries of the dashboards of chapter 5 of the first volume on the database built by
# build.sh, write the output of each script to out/<script>.out, and compare its summary, the
# number of rows of every answer, with expected/<script>.rows, the summary of the run of
# MobilityDB whose answers the notebooks of MobilitySpark and MobilityFlink reproduce. The full
# outputs reach tens of megabytes, so only their summaries are kept here. The structure follows
# chapter6/run_all.sh.
#
#   bash run_all.sh [script ...]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
export PGDATABASE=${PGDATABASE:-flights}
SCRIPTS=${*:-flights_dashboards flights_queries}
mkdir -p out
status=0
for s in $SCRIPTS; do
  echo "running: $s"
  psql -X -v ON_ERROR_STOP=1 -f "$s.sql" > "out/$s.out" 2>&1
  grep -E '^\([0-9]+ rows?\)$|^SELECT [0-9]+$|ERROR' "out/$s.out" > "out/$s.rows" || true
  if [ -f "expected/$s.rows" ]; then
    if diff -q "expected/$s.rows" "out/$s.rows" > /dev/null; then
      echo "  same as expected/$s.rows"
    else
      echo "  DIFFERS from expected/$s.rows: diff expected/$s.rows out/$s.rows"
      status=1
    fi
  fi
done
exit $status
