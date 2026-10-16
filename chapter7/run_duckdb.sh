#!/bin/bash
# Run one SQL script of this chapter in the DuckDB shell, over the database file it names, after
# replacing the environment variables of the README (and only those) by their values.
#
#   ./run_duckdb.sh <database> <script.sql>
#
# DuckDB must be the version of the README (v1.5.5); the extension is not signed, so the shell
# starts with -unsigned.
set -euo pipefail
: "${DUCKDB:=duckdb}"
[ $# -eq 2 ] || { echo "usage: $0 <database> <script.sql>" >&2; exit 2; }
envsubst '${AIS_DIR} ${PG_AIS} ${PG_HANOI} ${MOBILITYDUCK_EXTENSION} ${CH7_DB_DIR} ${CH7_PLAN_DIR}' \
  < "$2" | "$DUCKDB" -unsigned "$1"
