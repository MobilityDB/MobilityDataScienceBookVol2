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

# Draw the figures of the temporal point clouds and of the use case on seabed
# surveys into $OUT (default: out/ below the working directory), from the
# tables that ../soundings/load_soundings.sql adds to AIS_DB (default: ais):
# - export_survey_vessel.sh writes the layers of the survey vessel on its
#   October line, from which hybrid_pdf.py draws the vector PDFs of the point
#   cloud of ten seconds (job_pcl_swath.json, pointcloud_swath.pdf) and of the
#   whole line (job_pcl_line.json, pointcloud_line.pdf), and of the four
#   temporal types over the ten seconds (job_pcl_compare.json,
#   pointcloud_compare.pdf), and render.sh of chapter5/figures the images of
#   the traversed areas of the rigid geometry and of the circular buffer over
#   the ten seconds (job_excerpt_rigid.json, job_excerpt_buffer.json);
# - export_soundings.sh writes the layers of the two survey lines, from which
#   render.sh draws the overview and the close-up (job_soundings_overview.json,
#   job_soundings_closeup.json), and the soundings per ping in the square,
#   which soundings_per_ping.tex plots;
# - overlay_soundings.py, overlay_excerpt.py and overlay_pcl.py write the LaTeX
#   that the book inputs, with the labels, the legends and the scale bars set
#   in the style of the captions, and scalebars.py the scale bars of the maps
#   of the moving regions (*_scaled.tex), of which make_figures.sh draws the
#   noise region and the hull.
# The usual libpq variables (PGHOST, PGPORT, PGUSER) select the server. QGIS_PY
# is the Python of QGIS, as in make_figures.sh.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CH5="$HERE/../../chapter5/figures"
export OUT=${OUT:-$PWD/out}
export PGDATABASE=${AIS_DB:-ais}
mkdir -p "$OUT"
bash "$HERE/export_survey_vessel.sh"
bash "$HERE/export_soundings.sh"
cp "$HERE/hybrid_pdf.py" "$CH5/render_map.py" "$HERE"/job_pcl_*.json "$OUT/"
if [ -n "$QGIS_PY" ]; then
  RUN=($QGIS_PY)
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  RUN=(cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat")
fi
for m in swath line compare; do
  (cd "$OUT" && timeout 900 "${RUN[@]}" hybrid_pdf.py "job_pcl_$m.json" "pointcloud_$m.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true)
done
for j in excerpt_rigid excerpt_buffer soundings_overview soundings_closeup; do
  bash "$CH5/render.sh" "$HERE/job_$j.json"
done
# The areas that the captions of the two panels of the traversed areas state,
# those of the listing of the ten seconds of ../soundings/case_soundings.sql
read -r RIGID BUFFER < <(psql -X -At -F ' ' -c "
  SELECT round(ST_Area(traversedArea(trgeometry(
      geometry 'SRID=25832;Polygon((-3.75 -1.275,1.875 -1.275,3.75 0,
        1.875 1.275,-3.75 1.275,-3.75 -1.275))',
      tpose(Trip, 5 * pi() / 2 - azimuth(Trip))), true))),
    round(ST_Area(traversedArea(tcbuffer(Trip, tfloat(3.75, timeSpan(Trip))), true)))
  FROM (SELECT atTime(Trip, tstzspan '[2019-10-22 08:54:50+00, 2019-10-22 08:55:00+00]')
    AS Trip FROM Tracks WHERE Line = '20191022_085450_kh1910_400khz') t")
python3 "$HERE/overlay_excerpt.py" "$HERE" figs/chap5 "$RIGID" "$BUFFER" \
  "$OUT/excerpt_overlay.tex"
python3 "$HERE/overlay_soundings.py" "$HERE/job_soundings_overview.json" \
  "$HERE/job_soundings_closeup.json" "$OUT/soundings_trips.gpkg" figs/chap5 \
  "$OUT/soundings_overlay.tex"
cp "$HERE/soundings_per_ping.tex" "$OUT/"
python3 "$HERE/overlay_pcl.py" figs/chap3 "$OUT/pointcloud_overlay.tex"
python3 "$HERE/scalebars.py" figs/chap3 "$OUT"
