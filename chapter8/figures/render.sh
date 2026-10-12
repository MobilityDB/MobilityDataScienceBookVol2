#!/bin/bash
# Render the QGIS jobs that citibike_maps.py and flights_maps.py write into $OUT with qgis_map.py,
# each into the PDF its job names, as chapter5/figures/render.sh renders the jobs of chapter 5.
# Usage: render.sh <out> [<job>.json ...]      (default: every job of <out>)
# QGIS_PY is the Python of QGIS, for instance python3 on a Linux installation of QGIS; by default
# it is the QGIS 3.40 installation of Windows called from WSL, which needs <out> on a Windows
# drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(cd "$1" && pwd)
shift
cd "$OUT"
cp "$HERE/qgis_map.py" .
JOBS=${*:-$(ls *.json)}
for job in $JOBS; do
  job=$(basename "$job")
  out=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['output'])" "$job")
  if [ -n "$QGIS_PY" ]; then
    timeout 900 $QGIS_PY qgis_map.py "$job" "$out"
  else
    timeout 900 cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" \
      qgis_map.py "$job" "$out"
  fi 2>&1 | grep -E 'wrote|Error|Traceback|invalid' || true
done
