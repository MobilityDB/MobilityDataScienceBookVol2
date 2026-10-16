#!/bin/bash
# Draw the four maps of the figure of the Hermite curve of chapter 11 into $OUT (default: out/ below
# the working directory) as the vector PDF files hermite_<panel>.pdf that the book includes:
# export_hermite.py writes the GeoPackage and the job of each panel from the AIS database named by
# the usual libpq variables (PGDATABASE, PGHOST, PGPORT, PGUSER) once run_usecase.sh has run, and
# hybrid_pdf.py of chapter3/figures draws each job with QGIS over the OpenStreetMap vector tiles,
# with render_map.py of chapter5/figures. QGIS_PY is the Python of QGIS, for instance python3 on a
# Linux installation of QGIS; by default it is the QGIS 3.40 installation of Windows called from
# WSL, which needs $OUT on a Windows drive (/mnt/c/...).
#
#   OUT=/mnt/c/Users/<user>/hermite bash make_hermite.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
python3 "$HERE/export_hermite.py"
cp "$HERE/../../chapter3/figures/hybrid_pdf.py" "$HERE/../../chapter5/figures/render_map.py" "$OUT/"

if [ -n "$QGIS_PY" ]; then
  RUN=($QGIS_PY)
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  RUN=(cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat")
fi
cd "$OUT"
for p in gap4907 gap7902 turn209276000 turn210620000; do
  timeout 900 "${RUN[@]}" hybrid_pdf.py "job_$p.json" "hermite_$p.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done
ls -l hermite_*.pdf
