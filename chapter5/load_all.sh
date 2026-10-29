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

# Load the tables of the chapter into the AIS database of the book, which
# ../ais/build.sh builds with the AIS day (AISInput, AISClean, Vessels, Segments,
# Ships), from the files fetched by fetch_data.sh, in the order of the README:
# the ports and protected areas, the bathymetry, the hourly fields of the ocean
# models and of ERA5, and the bathymetry as RaQuet tiles. The database is the
# one named by the PostgreSQL environment variables (PGDATABASE, PGHOST, PGPORT,
# ...), and the files are read from $DATA (default: data/ below the working
# directory).
#
#   bash load_all.sh [aux] [ddm] [fields] [raquet]
#
# raquet needs the converter raquet-io 0.9.0 (pip install raquet-io==0.9.0) and
# the Python packages psycopg2 and pyarrow.
set -e
export DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
PARTS=${*:-aux ddm fields raquet}
PSQL="psql -X -q -v ON_ERROR_STOP=1"
cd "$HERE"

for part in $PARTS; do
  case $part in
  aux)
    bash build_aux_data.sh
    $PSQL -f load_aux_tables.sql
    ;;
  ddm)
    # The pixels a nearest-neighbour warp chooses depend on the blocks in which
    # gdalwarp processes the output, so the creation options are part of the
    # result: a tiled output gives the raster of the book.
    if [ ! -s "$DATA/ddm/ddm_50m_25832.tif" ]; then
      gdalwarp -q -t_srs EPSG:25832 -tr 50 50 -tap -r near \
        -co COMPRESS=DEFLATE -co TILED=YES \
        "$DATA/ddm/ddm_50m.dybde.tiff" "$DATA/ddm/ddm_50m_25832.tif"
    fi
    $PSQL -c "DROP TABLE IF EXISTS Bathymetry"
    (cd "$DATA/ddm" && raster2pgsql -s 25832 -t 256x256 -I -C -M -F \
      ddm_50m_25832.tif public.Bathymetry 2> /dev/null) | $PSQL
    ;;
  fields)
    bash prep_waves.sh
    bash load_waves.sh
    bash prep_fields.sh
    bash load_field.sh "$DATA/cmems/sst25832" SurfaceTemperature
    bash load_field.sh "$DATA/cmems/sss25832" SurfaceSalinity
    bash load_field.sh "$DATA/era5/wind25832" WindSpeed 50x50
    ;;
  raquet)
    mkdir -p "$DATA/raquet"
    if [ ! -s "$DATA/raquet/bathymetry.parquet" ]; then
      raquet-io convert raster "$DATA/ddm/ddm_50m_25832.tif" \
        "$DATA/raquet/bathymetry.parquet" --overviews none --resampling near
    fi
    python3 load_raquet.py "$DATA/raquet/bathymetry.parquet" BathymetryRaquet \
      "dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
    ;;
  *) echo "unknown part: $part"; exit 1 ;;
  esac
done
