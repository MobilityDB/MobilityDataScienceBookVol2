#!/bin/bash
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
