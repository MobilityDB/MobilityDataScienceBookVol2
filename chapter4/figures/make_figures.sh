#!/bin/bash
# Draw every figure of the chapter drawn from data into $OUT (default: out/
# below the working directory), from the AIS database built by ais_poses.sql and
# load_turbines.sql and the nuScenes database built by load_nuscenes.sql: each export script writes the
# layers and the spec of its map figures, and render.sh draws them with QGIS.
# The databases are named by the PostgreSQL environment variables and by AIS_DB
# and NUSCENES_DB (see figlib.py). With the default QGIS of Windows called from
# WSL, $OUT must be on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
python3 "$HERE/export_ais.py"
python3 "$HERE/export_nuscenes.py"
for s in ais nuscenes; do
  bash "$HERE/render.sh" "spec_$s.json"
done
