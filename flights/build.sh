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

# Build the flights tables of the book in the PostgreSQL database $PGDATABASE (default: flights)
# from the files that fetch_data.sh downloads into $DATA (default: data/ below the working
# directory): FlightsInput, FlightsPositions, FlightsDay and Flights, and CountriesInput, the
# countries of Natural Earth loaded with shp2pgsql of PostGIS. The usual libpq variables
# (PGHOST, PGPORT, PGUSER) select the server. DuckDB (the variable DUCKDB, default: duckdb) reads
# the Parquet files and keeps the state vectors at every tenth second of the day, the time step of
# the public samples of the OpenSky Network; the notebooks of MobilitySpark and MobilityFlink keep
# the same state vectors. The structure follows ais/build.sh.
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
# The countries of Natural Earth in WGS84, the table CountriesInput that flights_queries.sql reads
psql -q -c "DROP TABLE IF EXISTS CountriesInput"
shp2pgsql -s 4326 -g geom -D "$DATA/flights/countries/ne_50m_admin_0_countries.shp" CountriesInput |
  psql -q -v ON_ERROR_STOP=1
