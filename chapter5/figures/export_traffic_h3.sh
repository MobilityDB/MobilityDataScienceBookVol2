#!/bin/bash
# Export the layers of the traffic map: the H3 cells of resolution 7 with the
# vessel-hours of the AIS day (table CellTraffic of case_traffic.sql), and the
# busiest cell as a point. Writes to $OUT (default: the working directory);
# reads the database named by the PostgreSQL environment variables.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt POLYGON traffic_cells.gpkg "$PG" -nln cells -overwrite -sql \
  "SELECT Cell::text AS cell, Vessels AS vessels,
     EXTRACT(EPOCH FROM VesselTime) / 3600 AS hours, cellToBoundary(Cell) AS geom
   FROM CellTraffic"
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt POINT traffic_busiest.gpkg "$PG" -nln busiest -overwrite -sql \
  "SELECT 'Skagen' AS label, cellToPoint(Cell) AS geom
   FROM CellTraffic ORDER BY VesselTime DESC LIMIT 1"
for f in traffic_cells traffic_busiest; do ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
