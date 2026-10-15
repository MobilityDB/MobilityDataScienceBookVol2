#!/bin/bash
# Run the scripts of the chapter in the order of its sections on the database
# loaded by load_all.sh, write the output of each to out/<script>.out, and
# compare it with expected/<script>.out, the output of the run that produced the
# answers printed in the book.
#
#   bash run_all.sh [script ...]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
SCRIPTS=${*:-raster_tutorial map_algebra depth_under_vessel fields_along_trips \
  grids_and_cells case_clearance case_sea_state case_noise case_traffic \
  case_raquet exercises}
mkdir -p out
status=0
for s in $SCRIPTS; do
  echo "running: $s"
  psql -X -v ON_ERROR_STOP=1 -f "$s.sql" > "out/$s.out" 2>&1
  if [ -f "expected/$s.out" ]; then
    if diff -q "expected/$s.out" "out/$s.out" > /dev/null; then
      echo "  same as expected/$s.out"
    else
      echo "  DIFFERS from expected/$s.out: diff expected/$s.out out/$s.out"
      status=1
    fi
  fi
done
exit $status
