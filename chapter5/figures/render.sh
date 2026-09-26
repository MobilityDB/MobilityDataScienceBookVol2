#!/bin/bash
# Render one QGIS job of the chapter with render_map.py in the directory $OUT
# (default: the working directory), which holds the layers written by the
# export scripts; the job names its layers and its output relative to $OUT.
# Usage: render.sh <job.json>
# QGIS_PY is the Python of QGIS, for instance python3 on a Linux installation
# of QGIS; by default it is the QGIS 3.40 installation of Windows called from
# WSL, which needs $OUT on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
JOB=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=${OUT:-$PWD}
cd "$OUT"
cp "$HERE/render_map.py" "$JOB" .
if [ -n "$QGIS_PY" ]; then
  timeout 900 $QGIS_PY render_map.py "$(basename "$JOB")"
else
  timeout 900 cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" \
    render_map.py "$(basename "$JOB")"
fi 2>&1 | grep -E 'wrote|Error|Traceback|invalid' || true
