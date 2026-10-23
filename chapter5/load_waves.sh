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

# Section 8: load the hourly significant wave height rasters prepared by
# prep_waves.sh into WaveHeight(ValidTime, Rast), one row per tile of each
# hourly step, valid from the step until the next one.
set -e
DIR=${DATA:-$PWD/data}/cmems/waves25832
PSQL="psql -X -q -v ON_ERROR_STOP=1"
$PSQL -c "DROP TABLE IF EXISTS WaveHeightLoad; DROP TABLE IF EXISTS WaveHeight;"
first=1
for f in $DIR/vhm0_20260120T*.tif; do
  if [ $first = 1 ]; then mode=-c; first=0; else mode=-a; fi
  raster2pgsql -s 25832 -t 100x100 -F $mode $f WaveHeightLoad 2> /dev/null | $PSQL
done
$PSQL <<'EOF'
SET TimeZone = 'UTC';
CREATE TABLE WaveHeight AS
SELECT span(t, t + interval '1 hour', true, false) AS ValidTime, Rast
FROM (
  SELECT timestamptz '2026-01-20 00:00:00+00' +
      substring(filename from 'T([0-9]{2})\.tif$')::int * interval '1 hour' AS t,
    rast AS Rast
  FROM WaveHeightLoad ) l;
DROP TABLE WaveHeightLoad;
CREATE INDEX WaveHeight_Rast_Idx ON WaveHeight USING gist (ST_ConvexHull(Rast));
CREATE INDEX WaveHeight_ValidTime_Idx ON WaveHeight USING gist (ValidTime);
ANALYZE WaveHeight;
SELECT count(*) AS Tiles, count(DISTINCT ValidTime) AS Steps,
  min(lower(ValidTime)) AS First, max(upper(ValidTime)) AS Last
FROM WaveHeight;
EOF
