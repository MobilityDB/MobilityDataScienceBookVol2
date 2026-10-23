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

# Check that the AIS database built by build.sh keeps the same reports and segments as the
# MobilityLakehouse pipeline, which runs the same rules in DuckDB with MobilityDuck. The script
# fetches the MobilityLakehouse repository at the commit of lakehouse.env, converts the archives
# of the period into its raw zone, runs its cleaning and segmentation (run_clean.sh, stages 1 and
# 2), and compares the fingerprints of both results: the number of clean reports and of segments,
# and the MD5 of their keys (fingerprint.sql and fingerprint_duckdb.sql).
#
#   DUCKDB_ENGINE=<duckdb shell carrying MobilityDuck> bash check_duckdb.sh [day | month]
#
# The usual libpq variables select the database build.sh wrote ($PGDATABASE, default: ais).
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lakehouse.env"
export PGDATABASE=${PGDATABASE:-ais}
: "${DUCKDB_ENGINE:?set DUCKDB_ENGINE to a DuckDB shell carrying MobilityDuck}"
export DUCKDB_ENGINE

case ${1:-day} in
  day) LO=2026-01-20; HI=2026-01-21; PATTERN="aisdk-2026-01-20.zip" ;;
  month) LO=2026-01-01; HI=2026-02-01; PATTERN="aisdk-2026-01-*.zip" ;;
  *) echo "unknown period: $1"; exit 1 ;;
esac

LH=$DATA/MobilityLakehouse
if [ ! -d "$LH" ]; then
  git clone -q https://github.com/MobilityDB/MobilityLakehouse "$LH"
fi
git -C "$LH" fetch -q origin
git -C "$LH" checkout -q "$LAKEHOUSE_COMMIT"

ROOT=$DATA/lakehouse
mkdir -p "$ROOT"
bash "$LH/benchmark/ingest/raw_zone.sh" --zips "$DATA/ais" --pattern "$PATTERN" \
  --out "$ROOT/raw" --stage "$ROOT/stage" --duckdb "$LH/benchmark/planar/duckdb.sh"
OUT=$ROOT/stage/planar/${LO}_${HI}
ROOT=$ROOT LO=$LO HI=$HI OUT=$OUT STAGES="1 2" bash "$LH/benchmark/planar/run_clean.sh"

PG=$(psql -At -F ' ' -f "$HERE/fingerprint.sql")
DUCK=$("$LH/benchmark/planar/duckdb.sh" -noheader -list -separator ' ' \
  -cmd "SET VARIABLE out = '$OUT'" -f "$HERE/fingerprint_duckdb.sql")
echo "PostgreSQL:"; echo "$PG"
echo "DuckDB:"; echo "$DUCK"
if [ "$PG" = "$DUCK" ]; then echo "same reports and segments"; else
  echo "the two pipelines differ"; exit 1; fi
