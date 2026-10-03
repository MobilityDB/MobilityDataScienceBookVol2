#!/bin/bash
# Download the Citi Bike data of the book into the directory $DATA (default: data/ below the
# working directory): the trips of 2023 published by Citi Bike, one CSV file per part of a month
# in data/citibike/csv/, and the 2020 Neighborhood Tabulation Areas of New York City, release
# 26b, published by the Department of City Planning, in data/citibike/nynta2020_26b/. Nothing is
# redistributed in this repository: each file comes from its publisher. The helper fetch is
# #fetch of ais/fetch_data.sh.
#
#   bash fetch_data.sh
set -e
DATA=${DATA:-$PWD/data}
mkdir -p "$DATA/citibike/csv"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

fetch "https://s3.amazonaws.com/tripdata/2023-citibike-tripdata.zip" \
  "$DATA/citibike/2023-citibike-tripdata.zip"
fetch "https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/neighborhood-tabulation-areas/nynta2020_26b.zip" \
  "$DATA/citibike/nynta2020_26b.zip"

# The yearly archive holds one archive per month, each holding one or more CSV files
unzip -n -q -d "$DATA/citibike" "$DATA/citibike/2023-citibike-tripdata.zip" \
  '2023-citibike-tripdata/*.zip'
for m in "$DATA"/citibike/2023-citibike-tripdata/2023*.zip; do
  unzip -n -q -j -d "$DATA/citibike/csv" "$m" '*.csv'
done
unzip -n -q -d "$DATA/citibike" "$DATA/citibike/nynta2020_26b.zip"
