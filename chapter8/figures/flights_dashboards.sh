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

# Print the page of the Streamlit dashboards of the air traffic use case to flightsDashboards.pdf
# with chapter9/figures/capture.py, the script of the figure of the stream dashboards of chapter 9,
# once the six maps of the page are drawn and no panel is running. The page is that of the
# service dashboards of docker-compose-nozeppelin.yml, on port 8501, with the tables of the
# notebook "8.3 Create tables from scratch-flights-MobilitySpark" in the warehouse and those of
# dashboards/dashboards_tables.sql built (the button of dashboard 2 builds them).
#
#   bash flights_dashboards.sh <out>
#
# PYTHON is the Python with Playwright (default: python3).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mkdir -p "${1:?out}" && cd "$1" && pwd)
PY=${PYTHON:-python3}
$PY "$HERE/../../chapter9/figures/capture.py" \
  "http://localhost:8501/?embed=true" "$OUT/flightsDashboards.pdf" 1400 1810 \
  "document.querySelectorAll('[data-testid=\"stDeckGlJsonChart\"] canvas').length >= 6 && document.body.innerText.includes('come within') && document.body.innerText.includes('Cruising flights') && !document.querySelector('[data-testid=\"stSpinner\"]')" \
  25 1800
