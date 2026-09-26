#!/bin/bash
# Load the database of the chapter from the files fetched by fetch_data.sh, in
# the order of the README: the AIS day and its trips, the ports and protected
# areas, the bathymetry, the hourly fields of the ocean models and of ERA5, and
# the bathymetry as RaQuet tiles. The database is the one named by the
# PostgreSQL environment variables (PGDATABASE, PGHOST, PGPORT, ...), and the
# files are read from $DATA (default: data/ below the working directory).
#
#   bash load_all.sh [ais] [aux] [ddm] [fields] [raquet]
#
# raquet needs the converter raquet-io 0.9.0 (pip install raquet-io==0.9.0) and
# the Python packages psycopg2 and pyarrow.
set -e
export DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
PARTS=${*:-ais aux ddm fields raquet}
PSQL="psql -X -q -v ON_ERROR_STOP=1"
cd "$HERE"

for part in $PARTS; do
  case $part in
  ais)
    $PSQL -f ais_load.sql
    unzip -p "$DATA/ais/aisdk-2026-01-20.zip" | PGOPTIONS='-c datestyle=ISO,DMY' $PSQL -c \
      "\copy AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG, COG, Heading, IMO, CallSign, Name, ShipType, CargoType, Width, Length, TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType, SizeA, SizeB, SizeC, SizeD) FROM STDIN CSV HEADER"
    $PSQL -f ais_pipeline.sql
    ;;
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
