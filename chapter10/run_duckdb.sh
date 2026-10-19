#!/bin/bash
# Run one SQL script of this chapter in the DuckDB shell, after replacing the environment variables
# of the README (and only those) by their values, as chapter7/run_duckdb.sh does.
#
#   ./run_duckdb.sh <script.sql>
#
# DuckDB must be the version of the README (v1.5.5); the extension is not signed, so the shell
# starts with -unsigned. The scripts read Parquet files only, so the database is in memory.
set -euo pipefail
: "${DUCKDB:=duckdb}"
[ $# -eq 1 ] || { echo "usage: $0 <script.sql>" >&2; exit 2; }
envsubst '${LAKEHOUSE_RUN} ${MOBILITYDUCK_EXTENSION}' < "$1" | "$DUCKDB" -unsigned
