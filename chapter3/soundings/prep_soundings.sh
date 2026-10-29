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

# The soundings of the multibeam survey lines that fetch_soundings.sh puts into
# $DATA/soundings (default: data/soundings below the working directory), as
# one CSV file per line: the time of the ping in seconds since 1970, the ping
# number, the longitude, the latitude and the topography (positive upwards, in
# meters) of the sounding, its amplitude, and its beam number. A second file
# per line, ending in .nav, holds the navigation of the survey vessel: the time
# of each ping in seconds since 1970, and the longitude and the latitude of the
# vessel. mblist and mbnavlist of MB-System 5.8.2
# (https://github.com/dwcaress/MB-System, release 5.8.2; its master branch does
# not build with GDAL 3.8) read the raw files (format 89, Reson 7K); mblist
# writes the soundings it does not flag. A listing already present is kept.
# The variable MBSYSTEM names the directory where MB-System is installed
# (default: $BOOK_ENV/mbsystem, with BOOK_ENV as in tools/book_env/setup.sh).
#
#   bash prep_soundings.sh
set -e
SRC=${DATA:-$PWD/data}/soundings
MB=${MBSYSTEM:-${BOOK_ENV:-/mnt/bookdb/env}/mbsystem}
export LD_LIBRARY_PATH=$MB/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
for f in "$SRC"/*.s7k; do
  out=${f%.s7k}.csv
  if [ -s "$out" ]; then echo "present: $out"; else
    echo "converting: $f"
    "$MB/bin/mblist" -F89 -I "$f" -MA -OMNXYZB# -G, > "$out.part" && mv "$out.part" "$out"
  fi
  nav=${f%.s7k}.nav
  if [ -s "$nav" ]; then echo "present: $nav"; else
    "$MB/bin/mbnavlist" -F89 -I "$f" -OMXY -G, > "$nav.part" && mv "$nav.part" "$nav"
  fi
done
