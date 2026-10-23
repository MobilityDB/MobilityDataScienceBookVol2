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

# Download the data of the Delhi use case of chapter 6 into the directory $DATA (default: data/
# below the working directory): the air-quality observations of November and December 2020, one
# CSV file per day in data/delhi/, and the OpenStreetMap extract of India of January 1, 2021,
# the end of the observation period, whose administrative boundaries give the eleven districts
# of Delhi used in the chapter; Delhi has since been divided into thirteen districts, so the
# current extract gives other districts. The hourly weather of delhi_weather.csv is the only
# data held in this repository; each other file comes from its publisher. The helper fetch is
# #fetch of ais/fetch_data.sh.
#
#   bash fetch_data.sh
set -e
DATA=${DATA:-$PWD/data}
mkdir -p "$DATA/delhi"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

fetch "https://docs.mobilitydb.com/pub/Delhi_Pollution_2020-Nov-Dec.zip" "$DATA/delhi.zip"
fetch "https://download.geofabrik.de/asia/india-210101.osm.pbf" "$DATA/india-210101.osm.pbf"
unzip -n -j -d "$DATA/delhi" "$DATA/delhi.zip" '*_all.csv'
cp "$(cd "$(dirname "$0")" && pwd)/delhi_weather.csv" "$DATA/delhi_weather.csv"
