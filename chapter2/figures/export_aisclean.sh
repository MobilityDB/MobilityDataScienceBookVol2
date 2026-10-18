#!/bin/bash
# Export the table AISClean of the AIS database of the book (directory ais of this repository) to
# aisclean-2026-01-20.csv, the input of the PyMEOS and JMEOS examples of chapter 2. The file has
# the 26 columns of the files of the Danish Maritime Authority, with their names, in their order
# and with their timestamp format (day/month/year, UTC), so that the readers of the chapter read
# it as they read a DMA file. The reports are ordered by timestamp and MMSI.
#
#   PGDATABASE=ais CH2_DATA=<folder> ./export_aisclean.sh
#
# The variables PG* name the database (default: ais); the file is written into CH2_DATA (default:
# the folder data next to this script).
set -euo pipefail
export PGDATABASE=${PGDATABASE:-ais}
DATA=${CH2_DATA:-"$(cd "$(dirname "$0")" && pwd)/data"}
mkdir -p "$DATA"
OUT="$DATA/aisclean-2026-01-20.csv"
psql -v ON_ERROR_STOP=1 -c "\copy (
  SELECT to_char(T, 'DD/MM/YYYY HH24:MI:SS') AS \"# Timestamp\",
    TypeOfMobile AS \"Type of mobile\", MMSI AS \"MMSI\", Latitude AS \"Latitude\",
    Longitude AS \"Longitude\", NavigationalStatus AS \"Navigational status\", ROT AS \"ROT\",
    SOG AS \"SOG\", COG AS \"COG\", Heading AS \"Heading\", IMO AS \"IMO\",
    CallSign AS \"Callsign\", Name AS \"Name\", ShipType AS \"Ship type\",
    CargoType AS \"Cargo type\", Width AS \"Width\", Length AS \"Length\",
    TypeOfPositionFixingDevice AS \"Type of position fixing device\", Draught AS \"Draught\",
    Destination AS \"Destination\", ETA AS \"ETA\", DataSourceType AS \"Data source type\",
    SizeA AS \"A\", SizeB AS \"B\", SizeC AS \"C\", SizeD AS \"D\"
  FROM AISClean
  ORDER BY T, MMSI) TO '$OUT' CSV HEADER"
echo "$OUT: $(($(wc -l < "$OUT") - 1)) reports"
