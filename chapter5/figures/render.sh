#!/bin/bash
# Render one QGIS job of the chapter with render_map.py in the directory $OUT
# (default: the working directory), which holds the layers written by the
# export scripts; the job names its layers and its output relative to $OUT.
# Usage: render.sh <job.json>
# Needs kpsewhich for the fonts a job names. QGIS_PY is the Python of QGIS, for
# instance python3 on a Linux installation of QGIS; by default it is the QGIS
# 3.40 installation of Windows called from WSL, which needs $OUT on a Windows
# drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
JOB=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=${OUT:-$PWD}
cd "$OUT"
cp "$HERE/render_map.py" "$JOB" .
# The fonts the job names, such as the Latin Modern of the book, come from the TeX installation.
for f in $(python3 -c "import json,sys; print(' '.join(json.load(open(sys.argv[1])).get('fonts', [])))" "$JOB"); do
  [ -f "$f" ] || cp "$(kpsewhich "$f")" .
done
if [ -n "$QGIS_PY" ]; then
  timeout 900 $QGIS_PY render_map.py "$(basename "$JOB")"
else
  timeout 900 cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" \
    render_map.py "$(basename "$JOB")"
fi 2>&1 | grep -E 'wrote|font|Error|Traceback|invalid' || true
