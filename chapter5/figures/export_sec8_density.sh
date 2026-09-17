#!/bin/bash
# Export the layer of the Section 8 traffic map: the H3 cells of resolution 7
# with the vessel-hours of the AIS day, and the busiest cell as a point.
set -e
cd "${OUT:-$PWD}"
PG="PG:${PGCONN:-dbname=tess}"
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt POLYGON sec8_cells.gpkg "$PG" -nln cells -overwrite -sql \
  "SELECT Cell::text AS cell, Vessels AS vessels,
     EXTRACT(EPOCH FROM VesselTime) / 3600 AS hours, cellToBoundary(Cell) AS geom
   FROM CellTraffic"
ogr2ogr -f GPKG -a_srs EPSG:4326 -nlt POINT sec8_busiest.gpkg "$PG" -nln busiest -overwrite -sql \
  "SELECT 'Skagen' AS label, cellToPoint(Cell) AS geom
   FROM CellTraffic ORDER BY VesselTime DESC LIMIT 1"
for f in sec8_cells sec8_busiest; do ogrinfo -so $f.gpkg ${f#sec8_} | grep 'Feature Count'; done
