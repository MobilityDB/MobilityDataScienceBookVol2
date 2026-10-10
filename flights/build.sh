#!/bin/bash
# Build the flights tables of the book in the PostgreSQL database $PGDATABASE (default: flights)
# from the files that fetch_data.sh downloads into $DATA (default: data/ below the working
# directory): FlightsInput, FlightsDay and Flights. The usual libpq variables (PGHOST, PGPORT,
# PGUSER) select the server. DuckDB (the variable DUCKDB, default: duckdb) reads the Parquet
# files and keeps the state vectors at every tenth second of the day, the time step of the public
# samples of the OpenSky Network; the notebooks of MobilitySpark and MobilityFlink keep the same
# state vectors. The structure follows ais/build.sh.
#
#   bash build.sh
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
DUCKDB=${DUCKDB:-duckdb}
export PGDATABASE=${PGDATABASE:-flights}

psql -q -f "$HERE/flights_load.sql"
for f in "$DATA"/flights/parquet/hour=*/*.parquet; do
  echo "loading: $(basename "$(dirname "$f")")"
  "$DUCKDB" -c "COPY (SELECT time, icao24, lat, lon, velocity, heading, vertRate, callsign,
      onGround, alert, spi, squawk, baroAltitude, geoAltitude, lastPosUpdate, lastContact
    FROM read_parquet('$f') WHERE time % 10 = 0) TO '/dev/stdout' (FORMAT csv, HEADER)" |
    psql -c "\copy FlightsInputRaw FROM STDIN CSV HEADER"
done
psql -f "$HERE/flights_build.sql"
