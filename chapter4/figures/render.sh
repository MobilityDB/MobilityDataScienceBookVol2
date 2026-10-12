#!/bin/bash
# Render the map figures of a spec with render_figures.py in the directory $OUT
# (default: the working directory), which holds the layers and the spec written
# by an export script; the spec names its layers and its outputs relative to $OUT.
# Usage: render.sh <spec.json>
# QGIS_PY is the Python of QGIS, for instance python3 on a Linux installation of
# QGIS; by default it is the QGIS 3.40 installation of Windows called from WSL,
# which needs $OUT on a Windows drive (/mnt/c/...). The basemap tiles are fetched
# from OpenStreetMap.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$PWD}
cd "$OUT"
cp "$HERE/render_figures.py" .
if [ -n "$QGIS_PY" ]; then
  timeout 900 $QGIS_PY render_figures.py "$1"
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  timeout 900 cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat" \
    render_figures.py "$1"
fi 2>&1 | grep -E 'wrote|skipped|basemap|Error|Traceback' || true
