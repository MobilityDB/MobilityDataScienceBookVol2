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
