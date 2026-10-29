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

# Run the scripts of the chapter in the order of its sections on the AIS
# database of the book loaded by load_all.sh, write the output of each to
# out/<script>.out, and compare it with expected/<script>.out, the output of the
# run that produced the answers printed in the book. The noise of chapter 3
# (../chapter3/ships_noise.sql: ComputeVc, ComputeSL, VesselClass, PortAreas,
# and the column Noise of Ships), which case_clearance and case_noise read, is
# computed first when the database lacks it.
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
if [ "$(psql -X -At -c "SELECT count(*) FROM information_schema.columns
    WHERE table_name = 'ships' AND column_name = 'noise'")" = 0 ]; then
  echo "running: ../chapter3/ships_noise.sql"
  psql -X -q -v ON_ERROR_STOP=1 -f ../chapter3/ships_noise.sql > out/ships_noise.out 2>&1
fi
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
