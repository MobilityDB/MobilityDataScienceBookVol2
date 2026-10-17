#!/bin/bash
# Render the map figures of a spec as vector PDFs in the directory $OUT (default:
# the working directory), which holds the layers and the spec written by an
# export script; the spec names its layers and its outputs relative to $OUT.
# spec_jobs.py writes a job per figure, which chapter3/figures/storms_qgis_map.py
# draws over the OpenStreetMap Shortbread basemap of the book, as it draws the
# maps of vessels of chapter 3.
# Usage: render.sh <spec.json>
# QGIS_PY is the Python of QGIS, for instance python3 on a Linux installation of
# QGIS; by default it is the QGIS 3.40 installation of Windows called from WSL,
# which needs $OUT on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$PWD}
cd "$OUT"
cp "$HERE/../../chapter3/figures/storms_qgis_map.py" .
python3 "$HERE/spec_jobs.py" "$1" | while read -r job rest; do
  pdf=${job#job_}; pdf=${pdf%.json}.pdf
  if [ -n "$QGIS_PY" ]; then
    timeout 900 $QGIS_PY storms_qgis_map.py "$job" "$pdf"
  else
    QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
    timeout 900 cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat" \
      storms_qgis_map.py "$job" "$pdf" < /dev/null
  fi 2>&1 | grep -E 'wrote|Error|Traceback' || true
done
