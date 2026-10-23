#!/usr/bin/env bash
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

# Write the figures of chapter 10 as the PDF files the book includes, from a run of the
# MobilityLakehouse benchmark (https://github.com/MobilityDB/MobilityLakehouse, benchmark/planar/).
#
#   render_pdfs.sh
#
# The maps come from the QGIS jobs the benchmark writes: 79_layout_figures.sh writes job_<figure>.json
# and its GeoPackages into its STAGE for segment_raw, clean_segmented, tiling_L2_trip, tiling_L3_trip,
# q101_overview, q101_rodby, q101_puttgarden, usefulness_month and usefulness_query, and
# 77_cover_figures.sh writes job_trip_res8, job_trip_res9, job_region_res8 and job_region_res9 into
# its own STAGE. Each map is drawn here with the render_map.py of the benchmark (coverfig/), as a
# vector PDF by hybrid_pdf.py, except the two usefulness maps, whose month of tracks is one lossless
# image (tracks_image_pdf.py), and whose month-wide map draws its basemap from one merged GeoPackage
# of the OSM Shortbread tiles of zoom BASEMAP_ZOOM (extract_base.py), so that the page carries no
# tile edge. The two file grids of the usefulness figure are drawn by the benchmark's
# layoutfig/usefulness_grid.py, and the four in-file orderings by inorder_figures.py.
#
# Environment: LAKEHOUSE, the MobilityLakehouse checkout; LAYOUTFIG_STAGE, the STAGE of
# 79_layout_figures.sh (ROOT/stage/layoutfig); COVERFIG_STAGE, the STAGE of 77_cover_figures.sh
# (ROOT/stage/coverfig/layers); RUN, the run inorder_figures.py reads; OUT, where the PDF files go
# (figs/ beside this script); BASEMAP_ZOOM (6); QGIS_PY, the Python of QGIS, for instance python3 on
# a Linux installation of QGIS; by default it is the QGIS 3.40 installation of Windows called from
# WSL, which needs both stages on a Windows drive (/mnt/c/...), as the benchmark's renders do;
# PIKEPDF_PY, a Python with pikepdf and shapely (python3). The basemap is fetched over the network.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAKEHOUSE=${LAKEHOUSE:?LAKEHOUSE is required, the MobilityLakehouse checkout}
LAYOUTFIG_STAGE=${LAYOUTFIG_STAGE:?LAYOUTFIG_STAGE is required, the STAGE of 79_layout_figures.sh}
COVERFIG_STAGE=${COVERFIG_STAGE:?COVERFIG_STAGE is required, the STAGE of 77_cover_figures.sh}
OUT=${OUT:-$HERE/figs}
ZOOM=${BASEMAP_ZOOM:-6}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

qgis() {
  if [ -n "${QGIS_PY:-}" ]; then
    timeout 1800 $QGIS_PY "$@"
  else
    timeout 1800 cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" "$@"
  fi 2>&1 | grep -E 'wrote|Error|Traceback|invalid' || true
}

# One map of a stage: the writer, the job and the PDF are named relative to the stage, which is
# the working directory of QGIS, and the PDF is copied to OUT.
render() {
  local stage=$1 writer=$2 job=$3 pdf=$4
  shift 4
  cd "$stage"
  cp "$HERE/$writer" "$LAKEHOUSE/benchmark/planar/coverfig/render_map.py" .
  qgis "$writer" "$job" "$pdf" "$@"
  [ -s "$pdf" ] || { echo "render_pdfs.sh: no $stage/$pdf" >&2; exit 1; }
  cp "$pdf" "$OUT/$pdf"
  echo "copied $OUT/$pdf"
}

for fig in segment_raw clean_segmented tiling_L2_trip tiling_L3_trip q101_overview q101_rodby \
           q101_puttgarden; do
  render "$LAYOUTFIG_STAGE" hybrid_pdf.py "job_$fig.json" "$fig.pdf"
done
render "$LAYOUTFIG_STAGE" tracks_image_pdf.py job_usefulness_query.json usefulness_query.pdf \
  month_tracks

# The month-wide map: its Shortbread basemap replaced by the ocean, water polygons and streets of
# one merged GeoPackage over the map's extent, in the colours the job gives the basemap.
cd "$LAYOUTFIG_STAGE"
read -r X0 Y0 X1 Y1 < <(python3 - job_usefulness_month.json <<'EOF'
import json, sys
from osgeo import osr
job = json.load(open(sys.argv[1], encoding='utf-8'))
src, dst = osr.SpatialReference(), osr.SpatialReference()
src.SetFromUserInput(job['crs']); dst.ImportFromEPSG(3857)
for s in (src, dst):
    s.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
print(*osr.CoordinateTransformation(src, dst).TransformBounds(*job['extent'], 21))
EOF
)
python3 "$HERE/extract_base.py" "$ZOOM" "$X0" "$Y0" "$X1" "$Y1" "$LAYOUTFIG_STAGE/base_z$ZOOM.gpkg"
python3 - job_usefulness_month.json job_usefulness_month_base.json "base_z$ZOOM.gpkg" <<'EOF'
import json, sys
job = json.load(open(sys.argv[1], encoding='utf-8'))
layers = []
for spec in job['layers']:
    if spec['type'] != 'shortbread':
        layers.append(spec)
        continue
    water = spec.get('water', '#c6dcef')
    for name in ('ocean', 'water_polygons'):
        layers.append({'type': 'vector', 'path': sys.argv[3], 'layer': name, 'kind': 'fill',
                       'style': {'color': water, 'outline_color': water, 'outline_width': '0.1'}})
    if spec.get('streets'):
        layers.append({'type': 'vector', 'path': sys.argv[3], 'layer': 'streets', 'kind': 'line',
                       'style': {'line_color': spec['streets'], 'line_width': '0.1'}})
job['layers'] = layers
json.dump(job, open(sys.argv[2], 'w', encoding='utf-8'), indent=1)
EOF
render "$LAYOUTFIG_STAGE" tracks_image_pdf.py job_usefulness_month_base.json usefulness_month.pdf \
  month_tracks
# The tracks the query reads and the streets of the month-wide map carry vertices closer together than
# a pixel of the maps as the book prints them (0.48\textwidth, 56.16 mm): pdf_simplify.py of
# chapter7/figures simplifies them below half a printed pixel, with the Python of PIKEPDF_PY
for fig in usefulness_query usefulness_month; do
  "${PIKEPDF_PY:-python3}" "$HERE/../../chapter7/figures/pdf_simplify.py" "$OUT/$fig.pdf" "$OUT/$fig.pdf" 56.16
done

for fig in trip_res8 trip_res9 region_res8 region_res9; do
  render "$COVERFIG_STAGE" hybrid_pdf.py "job_$fig.json" "h3cover_$fig.pdf"
done

python3 "$LAKEHOUSE/benchmark/planar/layoutfig/usefulness_grid.py" \
  "$LAYOUTFIG_STAGE/use_files.csv" "$OUT/usefulness_files.pdf" "$OUT/usefulness_admitted.pdf"

if [ -n "${RUN:-}" ]; then
  EXT=pdf python3 "$HERE/inorder_figures.py" "" "$OUT"
else
  echo "render_pdfs.sh: RUN not set, the in-file orderings are not drawn" >&2
fi
