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

# Build the Citi Bike tables of the book (trips, nta, stations, station_duplicates and boroughs)
# as Delta tables in the warehouse $WAREHOUSE (default: data/citibike/warehouse below the working
# directory), from the files that fetch_data.sh downloads into $DATA (default: data/ below the
# working directory), then export the files that the chapter on stream processing replays with
# export_flink.sql, for the day $DAY (default: 2023-09-20, a Wednesday). Spark runs locally
# with $SPARK_HOME (Apache Spark 4.0.1), and fetches Apache Sedona 1.8.0 and Delta Lake 4.0.0 from
# Maven Central at its first start. The structure follows
# ais/build.sh; the repository holds no other launcher of Spark, so the helper sql is written
# beside #fetch of ais/fetch_data.sh.
#
#   bash build.sh
set -e
DATA=$(cd "${DATA:-$PWD/data}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
WAREHOUSE=${WAREHOUSE:-$DATA/citibike/warehouse}
: "${SPARK_HOME:?set SPARK_HOME to the directory of Apache Spark 4.0.1}"
mkdir -p "$WAREHOUSE"

sql() { # file
  "$SPARK_HOME/bin/spark-sql" \
    --master "local[*]" --driver-memory "${DRIVER_MEMORY:-16g}" \
    --packages org.apache.sedona:sedona-spark-shaded-4.0_2.13:1.8.0,org.datasyslab:geotools-wrapper:1.8.0-33.1,io.delta:delta-spark_2.13:4.0.0 \
    --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
    --conf spark.kryo.registrator=org.apache.sedona.core.serde.SedonaKryoRegistrator \
    --conf spark.sql.extensions=org.apache.sedona.sql.SedonaSqlExtensions,io.delta.sql.DeltaSparkSessionExtension \
    --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \
    --conf spark.sql.warehouse.dir="$WAREHOUSE" \
    --conf spark.driver.extraJavaOptions=-Dderby.system.home="$WAREHOUSE" \
    --conf spark.sql.session.timeZone=UTC \
    --hivevar data="$DATA" --hivevar day="${DAY:-2023-09-20}" \
    -f "$1"
}

sql "$HERE/citibike_build.sql"
sql "$HERE/export_flink.sql"
