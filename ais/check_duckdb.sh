#!/bin/bash
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
