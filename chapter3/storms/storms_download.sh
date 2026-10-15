#!/bin/sh
# -----------------------------------------------------------------------------
# Download the working best tracks of the tropical cyclones of one season from
# the GIS archive of the National Hurricane Center (NHC) of NOAA,
# https://www.nhc.noaa.gov/gis/, and unpack their shapefiles.
#
# Each cyclone has one archive <basin><number><year>_best_track.zip holding
# four shapefiles, named after the storm identifier, such as AL142024:
#   AL142024_pts        the observations of the track, every six hours and at
#                       landfall
#   AL142024_lin        the track as lines between the observations
#   AL142024_radii      the wind radii of 34, 50 and 64 knots at each synoptic
#                       time
#   AL142024_windswath  the wind swath, the area reached by each wind speed over
#                       the life of the cyclone
#
# Usage: storms_download.sh <year> [<basin>] [<directory>]
#   <basin>      al (Atlantic, the default), ep (eastern Pacific) or cp
#                (central Pacific)
#   <directory>  where the archives and the shapefiles are written, by default
#                ./data/<basin><year>
# -----------------------------------------------------------------------------
set -eu

YEAR=${1:?usage: storms_download.sh <year> [<basin>] [<directory>]}
BASIN=${2:-al}
DIR=${3:-./data/${BASIN}${YEAR}}
URL=https://www.nhc.noaa.gov/gis/best_track

mkdir -p "$DIR/zip" "$DIR/shape"
# The index of the archive lists every best track it publishes
ZIPS=$(curl -fsS "$URL/" | grep -o "${BASIN}[0-9][0-9]${YEAR}_best_track.zip" | sort -u)
if [ -z "$ZIPS" ]; then
  echo "No best track of the basin $BASIN for $YEAR at $URL" >&2
  exit 1
fi
for z in $ZIPS; do
  curl -fsS -o "$DIR/zip/$z" "$URL/$z"
  unzip -oq "$DIR/zip/$z" -d "$DIR/shape"
done
echo "$(echo "$ZIPS" | wc -l) storms in $DIR/shape"
