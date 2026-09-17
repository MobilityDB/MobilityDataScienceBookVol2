#!/bin/bash
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
