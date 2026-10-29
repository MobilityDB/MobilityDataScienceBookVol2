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

# Run the scripts of the temporal point clouds and of the use case on seabed
# surveys in the order of the chapter, on the database loaded by
# load_soundings.sql, write the output of each to out/<script>.out, and compare
# it with expected/<script>.out, the output of the run that produced the
# answers printed in the book, as ../../chapter5/run_all.sh does. The database
# is the one named by the PostgreSQL environment variables (PGDATABASE, PGHOST,
# PGPORT, ...).
#
#   bash run_all.sh [script ...]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
SCRIPTS=${*:-point_clouds case_soundings exercises}
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
