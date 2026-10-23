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

# Export the layers of the traffic map: the H3 cells of resolution 7 with the
# vessel-hours of the AIS day (table CellTraffic of case_traffic.sql), and the
# busiest cell as a point. Writes to $OUT (default: the working directory);
# reads the database named by the PostgreSQL environment variables.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
# The cells of each class of the legend are merged into one polygon whose hours
# are the lower bound of the class, so that the map draws the outline of each
# class instead of the edges the hexagons share.
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt MULTIPOLYGON traffic_cells.gpkg "$PG" -nln cells -overwrite -sql \
  "SELECT Hours AS hours, ST_Multi(ST_Union(cellToBoundary(Cell))) AS geom
   FROM (SELECT Cell, CASE WHEN h < 1 THEN 0 WHEN h < 5 THEN 1 WHEN h < 20 THEN 5
       WHEN h < 100 THEN 20 ELSE 100 END AS Hours
     FROM (SELECT Cell, EXTRACT(EPOCH FROM VesselTime) / 3600 AS h FROM CellTraffic) c) t
   GROUP BY Hours"
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt POINT traffic_busiest.gpkg "$PG" -nln busiest -overwrite -sql \
  "SELECT 'Skagen' AS label, cellToPoint(Cell) AS geom
   FROM CellTraffic ORDER BY VesselTime DESC LIMIT 1"
for f in traffic_cells traffic_busiest; do ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
