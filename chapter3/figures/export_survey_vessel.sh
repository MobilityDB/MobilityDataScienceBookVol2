#!/bin/bash
#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

# The layers of the maps of the survey vessel on its October line, from the
# tables Pings, Swaths and Tracks of ../soundings/load_soundings.sql, into $OUT
# (default: the working directory), in EPSG:25832. The vessel is placed as in
# the queries of ../soundings/case_soundings.sql: as a temporal rigid geometry,
# the pentagon of 7.5 m by 2.55 m centered on its antenna, moved by the temporal
# pose of its trip whose rotation is derived from the azimuth of the trip, and
# as a temporal circular buffer of radius 3.75 m centered on its antenna.
#
# - excerpt.gpkg, layer layers, the ten seconds from 08:54:50 to 08:55:00
#   (job_pcl_swath.json, job_pcl_compare.json, job_excerpt_rigid.json,
#   job_excerpt_buffer.json), one feature per value of its column layer:
#   antenna, the trajectory of the antenna; ta_rigid and ta_buffer, the
#   traversed areas of the rigid geometry and of the circular buffer; swath,
#   the swath of the pings; and, at each instant k = 0..5 two seconds apart,
#   hull<k> and buf<k>, the rigid geometry and the circular buffer, center<k>,
#   the antenna, and ping<k> and dots<k>, the footprint (the convex hull) and
#   the soundings of the ping nearest the instant;
# - fullline.gpkg, layer layers, the whole line (job_pcl_line.json): seven
#   pings evenly spread over the line, ping<i> as the footprint of the ping and
#   dots<i> as its soundings, and the rigid geometry at the same instants,
#   hull<i>, with the time t of each;
# - swath.gpkg and track.gpkg, the swath of the line and the trajectory of its
#   antenna, and frame.gpkg, the extent of job_pcl_swath.json, which
#   job_pcl_line.json draws as the frame of the ten seconds.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
export PGTZ=UTC
LINE=20191022_085450_kh1910_400khz
HULL="trgeometry(geometry 'SRID=25832;Polygon((-3.75 -1.275,1.875 -1.275,3.75 0,
  1.875 1.275,-3.75 1.275,-3.75 -1.275))', tpose(Trip, 5 * pi() / 2 - azimuth(Trip)))"
BUF="tcbuffer(Trip, tfloat(3.75, timeSpan(Trip)))"
W="tstzspan '[2019-10-22 08:54:50+00, 2019-10-22 08:55:00+00]'"
ogr2ogr -f GPKG -a_srs EPSG:25832 excerpt.gpkg "$PG" -nln layers -overwrite -sql \
  "WITH v AS (
     SELECT Trip, $HULL AS Hull, $BUF AS Buf FROM Tracks WHERE Line = '$LINE'),
   k AS (
     SELECT k, timestamptz '2019-10-22 08:54:50+00' + k * interval '2 s' AS t
     FROM generate_series(0, 5) k),
   p AS (
     SELECT k.k, (SELECT Patch FROM Pings WHERE Line = '$LINE'
       ORDER BY abs(extract(epoch FROM T - k.t)) LIMIT 1) AS Patch
     FROM k)
   SELECT 'antenna' AS layer, trajectory(atTime(Trip, $W)) AS geom FROM v
   UNION ALL SELECT 'ta_rigid', traversedArea(atTime(Hull, $W), true) FROM v
   UNION ALL SELECT 'ta_buffer', traversedArea(atTime(Buf, $W), true) FROM v
   UNION ALL SELECT 'hull' || k, valueAtTimestamp(Hull, t) FROM v, k
   UNION ALL SELECT 'buf' || k, valueAtTimestamp(Buf, t)::geometry FROM v, k
   UNION ALL SELECT 'center' || k, valueAtTimestamp(Trip, t) FROM v, k
   UNION ALL SELECT 'ping' || k, ST_ConvexHull(ST_Force2D(geometry(Patch))) FROM p
   UNION ALL SELECT 'swath', swath(atTime(Swath, $W)) FROM Swaths WHERE Line = '$LINE'
   UNION ALL SELECT 'dots' || k, ST_Force2D(geometry(Patch)) FROM p"
ogr2ogr -f GPKG -a_srs EPSG:25832 fullline.gpkg "$PG" -nln layers -overwrite -sql \
  "WITH p AS (
     SELECT row_number() OVER (ORDER BY T) - 1 AS n, count(*) OVER () AS c, T, Patch
     FROM Pings WHERE Line = '$LINE'),
   k AS (
     SELECT T, Patch, round(n * 6.0 / (c - 1))::int AS i FROM p
     WHERE n IN (SELECT round(j * (max(c) - 1) / 6.0) FROM p, generate_series(0, 6) j
       GROUP BY j))
   SELECT 'ping' || i AS layer, T::text AS t, ST_ConvexHull(ST_Force2D(geometry(Patch))) AS geom
   FROM k
   UNION ALL SELECT 'dots' || i, T::text, ST_Force2D(geometry(Patch)) FROM k
   UNION ALL SELECT 'hull' || i, T::text, valueAtTimestamp($HULL, k.T)
   FROM k, Tracks WHERE Line = '$LINE'"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POLYGON swath.gpkg "$PG" -nln swath -overwrite -sql \
  "SELECT swath(Swath) AS geom FROM Swaths WHERE Line = '$LINE'"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING track.gpkg "$PG" -nln track -overwrite -sql \
  "SELECT trajectory(Trip) AS geom FROM Tracks WHERE Line = '$LINE'"
read -r X0 Y0 X1 Y1 < <(python3 -c "import json, sys
print(*json.load(open(sys.argv[1]))['extent'])" "$HERE/job_pcl_swath.json")
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POLYGON frame.gpkg "$PG" -nln frame -overwrite -sql \
  "SELECT ST_MakeEnvelope($X0, $Y0, $X1, $Y1, 25832) AS geom"
for f in excerpt fullline swath track frame; do
  echo "$f: $(ogrinfo -so -al $f.gpkg | grep 'Feature Count')"
done
