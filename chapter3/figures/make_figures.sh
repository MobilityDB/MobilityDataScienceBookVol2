#!/bin/bash
# Draw the figures of the chapter drawn from data into $OUT (default: out/
# below the working directory):
# - the SQL scripts noise_region, exposure_w, encounter_sea, uwn_layers and
#   uwn_noise write the GeoJSON layers of the maps of the underwater-noise case
#   study from NOISE_DB (default: noise, built by tcbuffer_load_ais.sh and
#   completed with the table Exposure by tcbuffer_case_study.sql), and hull.sql
#   the layers of the hull of a ro-ro vessel from the table ShipsRigid of
#   chapter 4 in the AIS database of the book, AIS_DB (default: ais);
#   hybrid_pdf.py draws each job job_<map>.json as a vector PDF with QGIS over
#   the OpenStreetMap vector tiles, with render_map.py of chapter5/figures;
# - storms_export.sql writes the layers of the three maps of the Atlantic
#   storms from STORMS_DB (default: storms, built by storms/storms.sql with
#   year=2024), and render_storms.py draws each spec storms_<map>.json;
# - fig_dist_tcbuffer_point.py draws the turning point of the temporal distance
#   between a temporal circular buffer and a point, at the circle MobilityDB
#   answers.
# The usual libpq variables (PGHOST, PGPORT, PGUSER) select the server. QGIS_PY
# is the Python of QGIS, for instance python3 on a Linux installation of QGIS;
# by default it is the QGIS 3.40 installation of Windows called from WSL, as in
# chapter4/figures/render.sh, which needs $OUT on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CH5="$HERE/../../chapter5/figures"
export OUT=${OUT:-$PWD/out}
NOISE_DB=${NOISE_DB:-noise}
AIS_DB=${AIS_DB:-ais}
STORMS_DB=${STORMS_DB:-storms}
mkdir -p "$OUT"
for f in noise_region exposure_w encounter_sea uwn_layers uwn_noise; do
  psql -X -v ON_ERROR_STOP=1 -d "$NOISE_DB" -v out="$OUT" -f "$HERE/$f.sql"
done
psql -X -v ON_ERROR_STOP=1 -d "$AIS_DB" -v out="$OUT" -f "$HERE/hull.sql"
psql -X -At -v ON_ERROR_STOP=1 -d "$STORMS_DB" -f "$HERE/storms_export.sql" \
  > "$OUT/storms.geojson"
cp "$HERE/hybrid_pdf.py" "$CH5/render_map.py" "$HERE/render_storms.py" \
  "$HERE"/job_*.json "$HERE"/storms_*.json "$OUT/"

if [ -n "$QGIS_PY" ]; then
  RUN=($QGIS_PY)
else
  QGIS=$(ls -d "/mnt/c/Program Files/QGIS 3.40"* | sort -V | tail -1)
  RUN=(cmd.exe /c "C:\\Program Files\\$(basename "$QGIS")\\bin\\python-qgis-ltr.bat")
fi
cd "$OUT"
for m in noise_region:ais_noise_region hull:ais_hull_turn exposure_w:ais_exposure_w \
         encounter_sea:ais_encounter_sea traversed_area_uwn:traversed_area_uwn \
         shortest_line_uwn:shortest_line_uwn; do
  timeout 900 "${RUN[@]}" hybrid_pdf.py "job_${m%%:*}.json" "${m##*:}.pdf" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done
for m in tpoint tgeo tcbuffer; do
  timeout 900 "${RUN[@]}" render_storms.py "storms_$m.json" 2>&1 |
    grep -E 'wrote|Error|Traceback' || true
done

# The circle at the turning point and the end of the shortest line, as the
# database answers them
read -r CX CY R LX LY < <(psql -d "$NOISE_DB" -XAt -F ' ' -c "
  WITH d AS (SELECT tcbuffer '[Cbuffer(Point(4 4),2)@2001-01-01,
    Cbuffer(Point(16 15),5)@2001-01-04]' AS cb, geometry 'Point(14 3)' AS q),
  c AS (SELECT valueAtTimestamp(cb, getTimestamp(nearestApproachInstant(cb, q))) AS c,
    ST_StartPoint(shortestLine(cb, q)) AS l FROM d)
  SELECT ST_X(point(c)), ST_Y(point(c)), radius(c), ST_X(l), ST_Y(l) FROM c")
python3 "$HERE/fig_dist_tcbuffer_point.py" "$CX" "$CY" "$R" "$LX" "$LY" \
  "$OUT/dist_tcbuffer_point.pdf"
