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

# Run one SQL script of this chapter in the DuckDB shell, over the database file it names, after
# replacing the environment variables of the README (and only those) by their values.
#
#   ./run_duckdb.sh <database> <script.sql>
#
# DuckDB must be the version of the README (v1.5.6); the extension is not signed, so the shell
# starts with -unsigned.
set -euo pipefail
: "${DUCKDB:=duckdb}"
[ $# -eq 2 ] || { echo "usage: $0 <database> <script.sql>" >&2; exit 2; }
envsubst '${AIS_DIR} ${PG_AIS} ${PG_HANOI} ${HANOI_DIR} ${MOBILITYDUCK_EXTENSION} ${CH7_DB_DIR} ${CH7_PLAN_DIR}' \
  < "$2" | "$DUCKDB" -unsigned "$1"
