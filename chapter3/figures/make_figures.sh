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

# Draw the figures of the chapter drawn from data into $OUT (default: out/
# below the working directory):
# - the SQL scripts exposure_w, uwn_layers and uwn_noise write the GeoJSON
#   layers of three maps of the underwater-noise case study, and hull.sql the
#   layers of the hull of a ro-ro vessel from the table ShipsRigid of chapter 4,
#   all from the AIS database of the book, AIS_DB (default: ais), after
#   ships_noise.sql and tcbuffer_case_study.sql; hybrid_pdf.py draws each job
#   job_<map>.json as a vector PDF with QGIS over the OpenStreetMap vector tiles,
#   with render_map.py of chapter5/figures;
# - noise_region_job.py and encounter_sea_job.py write the layers and the jobs
#   of the noise region of the fishing vessel and of the acoustic encounter at
#   sea from the same database, and storms_qgis_map.py draws them;
# - storms_jobs.py writes the layers and the jobs of the three maps of the
#   Atlantic storms from STORMS_DB (default: storms, built by storms/storms.sql
#   with year=2024), and storms_qgis_map.py draws each job storms_<map>.json;
# - fig_dist_tcbuffer_point.py draws the turning point of the temporal distance
#   between a temporal circular buffer and a point, at the circle MobilityDB
#   answers;
# - make_figures_soundings.sh draws the figures of the temporal point clouds and
#   of the use case on seabed surveys, from the tables of
#   ../soundings/load_soundings.sql in the same database, and the scale bars of
#   the maps of the moving regions, with scalebars.py.
# The usual libpq variables (PGHOST, PGPORT, PGUSER) select the server. QGIS_PY
# is the Python of QGIS, for instance python3 on a Linux installation of QGIS;
# by default it is the QGIS 3.40 installation of Windows called from WSL, as in
# chapter4/figures/render.sh, which needs $OUT on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CH5="$HERE/../../chapter5/figures"
export OUT=${OUT:-$PWD/out}
AIS_DB=${AIS_DB:-ais}
STORMS_DB=${STORMS_DB:-storms}
mkdir -p "$OUT"
for f in exposure_w uwn_layers uwn_noise; do
  psql -X -v ON_ERROR_STOP=1 -d "$AIS_DB" -v out="$OUT" -f "$HERE/$f.sql"
done
psql -X -v ON_ERROR_STOP=1 -d "$AIS_DB" -v out="$OUT" -f "$HERE/hull.sql"
python3 "$HERE/storms_jobs.py" "$STORMS_DB" "$OUT"
AIS_DB="$AIS_DB" python3 "$HERE/noise_region_job.py" "$OUT"
AIS_DB="$AIS_DB" python3 "$HERE/encounter_sea_job.py" "$OUT"
cp "$HERE/hybrid_pdf.py" "$CH5/render_map.py" "$HERE/storms_qgis_map.py" \
  "$HERE"/job_*.json "$OUT/"

if [ -n "$QGIS_PY" ]; then
  RUN=($QGIS_PY)
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  RUN=(cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat")
fi
cd "$OUT"
for m in hull:ais_hull_turn exposure_w:ais_exposure_w \
         traversed_area_uwn:traversed_area_uwn shortest_line_uwn:shortest_line_uwn; do
  timeout 900 "${RUN[@]}" hybrid_pdf.py "job_${m%%:*}.json" "${m##*:}.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done
for m in tpoint tgeo tcbuffer tampa; do
  timeout 900 "${RUN[@]}" storms_qgis_map.py "storms_$m.json" "storms_$m.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done
# The wind radii of the 2024 storms are arcs of many vertices, closer together than
# a pixel of the map as the book prints it (\textwidth, 117 mm): pdf_simplify.py of
# chapter7/figures simplifies them below half a printed pixel, with the Python of
# PIKEPDF_PY (pikepdf and shapely)
"${PIKEPDF_PY:-python3}" "$HERE/../../chapter7/figures/pdf_simplify.py" \
  storms_tgeo.pdf storms_tgeo.pdf 117
for m in ais_noise_region ais_encounter_sea_a ais_encounter_sea_b; do
  timeout 900 "${RUN[@]}" storms_qgis_map.py "$m.json" "$m.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done

# The circle at the turning point and the end of the shortest line, as the
# database answers them
read -r CX CY R LX LY < <(psql -d "$AIS_DB" -XAt -F ' ' -c "
  WITH d AS (SELECT tcbuffer '[Cbuffer(Point(4 4),2)@2001-01-01,
    Cbuffer(Point(16 15),5)@2001-01-04]' AS cb, geometry 'Point(14 3)' AS q),
  c AS (SELECT valueAtTimestamp(cb, getTimestamp(nearestApproachInstant(cb, q))) AS c,
    ST_StartPoint(shortestLine(cb, q)) AS l FROM d)
  SELECT ST_X(point(c)), ST_Y(point(c)), radius(c), ST_X(l), ST_Y(l) FROM c")
python3 "$HERE/fig_dist_tcbuffer_point.py" "$CX" "$CY" "$R" "$LX" "$LY" \
  "$OUT/dist_tcbuffer_point.pdf"
AIS_DB="$AIS_DB" bash "$HERE/make_figures_soundings.sh"
