#!/bin/bash
# Download the flights data of the book into the directory $DATA (default: data/ below the
# working directory): the state vectors of Sunday, March 1, 2026, that the OpenSky Network
# publishes as a sample of the table state_vectors of its historical database, one Parquet file
# per hour, into data/flights/parquet/hour=<Unix time of the hour>/, and the countries of Natural
# Earth into data/flights/countries/. The names of the Parquet files are read from the listing of
# the bucket. Nothing is redistributed in this repository: each file
# comes from its publisher. The helper fetch is #fetch of ais/fetch_data.sh.
#
#   bash fetch_data.sh
set -e
DATA=${DATA:-$PWD/data}
BUCKET=https://s3.opensky-network.org/data-samples
PREFIX=trino-tables/state_vectors/
mkdir -p "$DATA/flights/parquet"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

for key in $(curl -fsL "$BUCKET?list-type=2&prefix=$PREFIX" | grep -oE "<Key>[^<]*\.parquet" |
    sed 's/<Key>//'); do
  file="$DATA/flights/parquet/${key#"$PREFIX"}"
  mkdir -p "$(dirname "$file")"
  fetch "$BUCKET/$key" "$file"
done

# The countries of Natural Earth at the scale 1:50m, a shapefile in WGS84, which the queries of
# chapter 8 read, into data/flights/countries/
mkdir -p "$DATA/flights/countries"
fetch https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip \
  "$DATA/flights/countries/ne_50m_admin_0_countries.zip"
unzip -o -q -d "$DATA/flights/countries" "$DATA/flights/countries/ne_50m_admin_0_countries.zip"
