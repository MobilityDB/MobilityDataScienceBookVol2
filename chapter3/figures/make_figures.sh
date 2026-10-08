#!/bin/bash
# Draw the figures of the chapter drawn from data into $OUT (default: out/
# below the working directory):
# - export_figures.py writes the layers and the spec of the four AIS maps from
#   the database of the use case (NOISE_DB, default noise, built by
#   tcbuffer_load.sql and the queries of tcbuffer_case_study.sql) and from the
#   AIS database of chapter 4 (AIS_DB, default ais), and render.sh of chapter 4
#   draws them with QGIS;
# - fig_dist_tcbuffer_point.py draws the turning point of the temporal distance
#   between a temporal circular buffer and a point, at the circle MobilityDB
#   answers.
# The databases are named by the PostgreSQL environment variables; the helpers
# and the renderer are those of chapter4/figures. With the default QGIS of
# Windows called from WSL, $OUT must be on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CH4="$HERE/../../chapter4/figures"
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
PYTHONPATH="$CH4" python3 "$HERE/export_figures.py"
bash "$CH4/render.sh" spec_ch3.json
# The circle at the turning point and the end of the shortest line, as the
# database answers them
read -r CX CY R LX LY < <(psql -d "${NOISE_DB:-noise}" -XAt -F ' ' -c "
  WITH d AS (SELECT tcbuffer '[Cbuffer(Point(4 4),2)@2001-01-01,
    Cbuffer(Point(16 15),5)@2001-01-04]' AS cb, geometry 'Point(14 3)' AS q),
  c AS (SELECT valueAtTimestamp(cb, getTimestamp(nearestApproachInstant(cb, q))) AS c,
    ST_StartPoint(shortestLine(cb, q)) AS l FROM d)
  SELECT ST_X(point(c)), ST_Y(point(c)), radius(c), ST_X(l), ST_Y(l) FROM c")
python3 "$HERE/fig_dist_tcbuffer_point.py" "$CX" "$CY" "$R" "$LX" "$LY" \
  "$OUT/dist_tcbuffer_point.pdf"
