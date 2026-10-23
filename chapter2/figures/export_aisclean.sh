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
