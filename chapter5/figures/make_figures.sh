#!/bin/bash
# Draw every map figure of the chapter into $OUT (default: out/ below the
# working directory) from the database loaded by load_all.sh after run_all.sh:
# each export script writes the layers of its figure, render.sh draws the
# figure with QGIS, and cellgrids.py lays out the figure of the three cell grids
# from the image of the MobilityDB manual. With the default QGIS of Windows
# called from WSL, $OUT must be on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
export DATA=${DATA:-$PWD/data}
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
for f in bathymetry_laeso depth_under_vessel traffic_h3 seabed; do
  bash "$HERE/export_$f.sh"
done
for j in bathymetry_laeso depth_under_vessel traffic_h3 seabed_slope seabed_tpi; do
  bash "$HERE/render.sh" "$HERE/job_$j.json"
done
curl -fsSL -o "$OUT/cellindex.png" \
  https://raw.githubusercontent.com/MobilityDB/MobilityDB/688ef3e12bcff88de44c42ca6e71a554c1800c60/doc/images/cellindex.png
python3 "$HERE/cellgrids.py" "$OUT/cellindex.png" "$OUT/cellgrids.png"
# The labels and the legend of the depth under the vessel are LaTeX, in the style
# of the captions, drawn over the image by depth_under_vessel_overlay.tex.
python3 "$HERE/overlay_depth_under_vessel.py" "$HERE/job_depth_under_vessel.json" \
  "$OUT/vessel_reports.gpkg" figs/tessellations/depth_under_vessel '0.85\textwidth' \
  "$OUT/depth_under_vessel_overlay.tex"
