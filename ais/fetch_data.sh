#!/bin/bash
# Download the AIS data of the book into the directory $DATA (default: data/ below the working
# directory): the daily archives of the Danish Maritime Authority, and the table of Maritime
# Identification Digits of the MobilityLakehouse repository, at the commit whose rules the
# cleaning follows. Nothing is redistributed in this repository: each file comes from its
# publisher. The helper fetch is #fetch of chapter5/fetch_data.sh.
#
#   bash fetch_data.sh [day | month]
#
# day (the default) fetches January 20, 2026, the day of the single-day chapters; month fetches
# the 31 days of January 2026, the month of the lakehouse chapter.
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lakehouse.env"
mkdir -p "$DATA/ais"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

case ${1:-day} in
  day) DAYS="2026-01-20" ;;
  month) DAYS=$(seq -f "2026-01-%02g" 1 31) ;;
  *) echo "unknown period: $1"; exit 1 ;;
esac
for d in $DAYS; do
  fetch "http://aisdata.ais.dk/aisdk-$d.zip" "$DATA/ais/aisdk-$d.zip"
done

R="https://raw.githubusercontent.com/MobilityDB/MobilityLakehouse/$LAKEHOUSE_COMMIT/benchmark/planar"
for f in itu_mid.csv itu_mid.LICENSE itu_mid.NOTICE; do
  fetch "$R/$f" "$DATA/$f"
done
