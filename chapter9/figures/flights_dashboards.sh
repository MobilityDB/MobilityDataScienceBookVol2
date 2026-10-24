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

# Print the Streamlit dashboards of the air traffic stream to flightsStreamDashboards.pdf while
# the day is replayed: start Kafka, the walk, the dashboards job and the application, replay the
# day at the default speed-up of replay_flights.py, print the page with capture.py once the
# producer has sent the hour <hour> (default: 10) and the dashboards show the positions of that
# hour, then stop everything.
#
#   bash flights_dashboards.sh <out> [<hour>]
#
# Run it from the directory that holds data/ (the Parquet day that flights/fetch_data.sh
# downloads) and src/libmeos.so, from which JMEOS loads MEOS, after building the walk as the
# README of the chapter builds it. MEOS_LIB is the directory of the libmeos.so that MobilityFlink
# built, PYTHON the Python with PyFlink, confluent-kafka, duckdb and Playwright (default: python3)
# and STREAMLIT the streamlit command (default: streamlit). The Kafka broker runs in the Docker
# container flights-kafka on port 9092 and the application on port 8501.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
EX=$(cd "$HERE/../Flink_Examples/flights_stream" && pwd)
OUT=$(mkdir -p "${1:?out}" && cd "$1" && pwd)
AFTER=${2:-10}
PY=${PYTHON:-python3}
ST=${STREAMLIT:-streamlit}
PYLIB=$($PY -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
WALKCP="$PYLIB/*:$EX/walk/target/flights-walk-1.0.jar:$EX/walk/target/lib/*"
export MOBILITYFLINK_JARS=$(ls $EX/walk/target/lib/*.jar | tr '\n' ';' | sed 's/;$//')
export JVM_ARGS="-Xmx1200m"
export LD_LIBRARY_PATH=${MEOS_LIB:?directory of libmeos.so}
trap 'kill $(jobs -p) 2>/dev/null; pkill -f "streamlit run app.py --server.headless true --server.port 8501"; pkill -f PythonGatewayServer; pkill -f flights.FlightsWalk; sleep 3; docker rm -f flights-kafka >/dev/null 2>&1' EXIT

echo "[$(date +%T)] start kafka"; free -g | head -2
docker rm -f flights-kafka >/dev/null 2>&1
docker run -d --name flights-kafka -p 9092:9092 -e KAFKA_HEAP_OPTS="-Xmx1g -Xms1g" \
  apache/kafka:3.9.1 >/dev/null
until docker exec flights-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --list >/dev/null 2>&1; do sleep 2; done
for t in flights-states flights-positions flights-dropped climbing-brussels close-pairs \
    traffic-per-hour; do
  docker exec flights-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic $t --partitions 1 >/dev/null
done

echo "[$(date +%T)] start the jobs and the app"
java -Xmx1200m -cp "$WALKCP" flights.FlightsWalk > "$OUT/walk.log" 2>&1 &
$PY $EX/flights_dashboards.py > "$OUT/dashboards.log" 2>&1 &
(cd $EX && $ST run app.py --server.headless true --server.port 8501 \
  --server.enableStaticServing true --theme.base light --client.toolbarMode viewer > "$OUT/app.log" 2>&1) &
sleep 40

echo "[$(date +%T)] replay at the default speed-up"
$PY $EX/replay_flights.py > "$OUT/replay.log" 2>&1 &
# The capture, once the replay has sent the hour AFTER
until grep -q "up to $(printf %02d $AFTER):59:50" "$OUT/replay.log"; do sleep 5; done
echo "[$(date +%T)] capture after hour $AFTER"
$PY $HERE/capture.py \
  http://localhost:8501 "$OUT/flightsStreamDashboards.pdf" 1400 1477 \
  "document.body.innerText.includes('rows read from Kafka') && document.body.innerText.includes('Positions $(printf %02d $AFTER):00')" \
  25 1800 > "$OUT/capture.log" 2>&1
echo "[$(date +%T)] capture rc=$?"; tail -2 "$OUT/replay.log"
free -g | head -2
echo "[$(date +%T)] stop"
