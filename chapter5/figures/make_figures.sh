#!/bin/bash
# Draw every map figure of the chapter into $OUT (default: out/ below the
# working directory) from the database loaded by load_all.sh after run_all.sh:
# each export script writes the layers of its figure, hybrid_pdf.py of
# chapter3/figures draws each job job_<figure>.json with QGIS and render_map.py
# as the vector PDF <figure>.pdf the book includes (the basemap, cells, tracks
# and outlines as vectors, a raster data layer as an embedded image), and
# export_cellgrids.sql, cellgrids_panels.py, and cellgrids_compose.tex draw the
# figure of the three cell grids as cellgrids.pdf. QGIS_PY is the Python of QGIS, for instance python3 on a
# Linux installation of QGIS; by default it is the QGIS 3.40 installation of
# Windows called from WSL, which needs $OUT on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
export DATA=${DATA:-$PWD/data}
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
for f in bathymetry_laeso depth_under_vessel traffic_h3 seabed; do
  bash "$HERE/export_$f.sh"
done
# The traffic map spans Denmark and its neighbours, so its basemap is one merged
# GeoPackage of the OSM Shortbread tiles of zoom 5 (extract_base.py of
# chapter10/figures, which needs shapely and the GDAL bindings), whose water
# draws in under a second; the extent is that of job_traffic_h3.json in
# EPSG:3857 with a margin.
python3 "$HERE/../../chapter10/figures/extract_base.py" 5 780000 7150000 1800000 8050000 \
  "$OUT/traffic_base.gpkg"
cp "$HERE/../../chapter3/figures/hybrid_pdf.py" "$HERE/render_map.py" "$HERE"/job_*.json "$OUT/"
if [ -n "$QGIS_PY" ]; then
  RUN=($QGIS_PY)
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  RUN=(cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat")
fi
for j in bathymetry_laeso depth_under_vessel traffic_h3 seabed_slope seabed_tpi; do
  (cd "$OUT" && timeout 900 "${RUN[@]}" hybrid_pdf.py "job_$j.json" "$j.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true)
done
psql -X -v out="$OUT" -f "$HERE/export_cellgrids.sql"
cp "$HERE/cellgrids_panels.py" "$HERE/cellgrids_compose.tex" "$OUT/"
(cd "$OUT" && timeout 900 "${RUN[@]}" cellgrids_panels.py . 2>&1 | grep -E 'wrote|Error|Traceback' || true)
(cd "$OUT" && pdflatex -interaction=nonstopmode cellgrids_compose.tex > /dev/null &&
  mv cellgrids_compose.pdf cellgrids.pdf)
# The labels and the legends of the bathymetry around Laeso and of the depth under
# the vessel are LaTeX, in the style of the captions, drawn over the images by
# bathymetry_laeso_overlay.tex and depth_under_vessel_overlay.tex.
python3 "$HERE/overlay_bathymetry_laeso.py" "$HERE/job_bathymetry_laeso.json" \
  figs/chap5/bathymetry_laeso '0.85\textwidth' "$OUT/bathymetry_laeso_overlay.tex"
python3 "$HERE/overlay_depth_under_vessel.py" "$HERE/job_depth_under_vessel.json" \
  "$OUT/vessel_reports.gpkg" figs/chap5/depth_under_vessel '0.85\textwidth' \
  "$OUT/depth_under_vessel_overlay.tex"
