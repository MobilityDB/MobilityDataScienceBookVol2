#!/bin/bash
# Download the flights data of the book into the directory $DATA (default: data/ below the
# working directory): the state vectors that the OpenSky Network publishes for one day, one
# archive per hour, each holding one gzipped CSV file, unpacked into data/flights/csv/. The day is
# $DAY (default: 2022-06-27, the last day of the public samples). Nothing is redistributed in
# this repository: each file comes from its publisher. The helper fetch is #fetch of
# ais/fetch_data.sh.
#
#   bash fetch_data.sh
set -e
DATA=${DATA:-$PWD/data}
DAY=${DAY:-2022-06-27}
mkdir -p "$DATA/flights/tar" "$DATA/flights/csv"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

for h in $(seq -w 0 23); do
  name="states_$DAY-$h"
  fetch "https://s3.opensky-network.org/data-samples/states/$DAY/$h/$name.csv.tar" \
    "$DATA/flights/tar/$name.csv.tar"
  # Each archive holds the CSV file, gzipped, besides a licence and a readme
  tar -x -C "$DATA/flights/csv" -f "$DATA/flights/tar/$name.csv.tar" "$name.csv.gz"
done
