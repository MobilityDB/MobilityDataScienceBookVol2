#!/bin/bash
# One bounded session of the four continuous queries of flights_queries.py: start Kafka, replay
# the day at full speed, run the walk and then the queries over the topics up to their end,
# timing each, dump the topics hourly-trips, brussels-arrivals, airborne-hourly and holding as
# JSON lines into <out>, then stop Kafka. compare_queries.py compares the last two dumps with the
# answers of MobilityDB, and chapter8/figures/flights_stream_maps.py draws the first two.
#
#   bash queries_session.sh <out>
#
# Run it from the directory that holds data/ (the Parquet day that flights/fetch_data.sh
# downloads) and src/libmeos.so, from which JMEOS loads MEOS, after building the walk as the
# README of the chapter builds it. MEOS_LIB is the directory of the libmeos.so that MobilityFlink
# built and PYTHON the Python with PyFlink and confluent-kafka (default: python3). The Kafka
# broker runs in the Docker container flights-kafka on port 9092.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
EX=$(cd "$HERE/.." && pwd)
OUT=$(mkdir -p "${1:?out}" && cd "$1" && pwd)
LIB=$EX/walk/target/lib
QUERIES=$EX/flights_queries.py
PY=${PYTHON:-python3}
PYLIB=$($PY -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
WALKCP="$PYLIB/*:$EX/walk/target/flights-walk-1.0.jar:$LIB/*"
export MOBILITYFLINK_JARS=$(ls $LIB/*.jar | tr '\n' ';' | sed 's/;$//')
export JVM_ARGS="-Xmx1200m"
export LD_LIBRARY_PATH=${MEOS_LIB:?directory of libmeos.so}
JAVA_OPENS="--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED"
KT=/opt/kafka/bin
trap 'docker rm -f flights-kafka >/dev/null 2>&1' EXIT

echo "[$(date +%T)] start kafka"
docker rm -f flights-kafka >/dev/null 2>&1
docker run -d --name flights-kafka -p 9092:9092 -e KAFKA_HEAP_OPTS="-Xmx1g -Xms1g" \
  apache/kafka:3.9.1 >/dev/null
until docker exec flights-kafka $KT/kafka-topics.sh --bootstrap-server localhost:9092 \
  --list >/dev/null 2>&1; do sleep 2; done
for t in flights-states flights-positions flights-dropped hourly-trips brussels-arrivals airborne-hourly holding; do
  docker exec flights-kafka $KT/kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic $t --partitions 1 >/dev/null
done

echo "[$(date +%T)] replay at full speed"
s=$(date +%s)
$PY $EX/replay_flights.py 1e12 > "$OUT/replay.log" 2>&1
rc=$?
echo "[$(date +%T)] replay rc=$rc seconds=$(( $(date +%s) - s ))"; tail -2 "$OUT/replay.log"
[ $rc -eq 0 ] || exit 1

echo "[$(date +%T)] walk bounded"
s=$(date +%s)
java -Xmx1200m $JAVA_OPENS -cp "$WALKCP" flights.FlightsWalk bounded > "$OUT/walk.log" 2>&1
echo "[$(date +%T)] walk rc=$? seconds=$(( $(date +%s) - s ))"
grep -v '^Running on\|library path\|Loading library' "$OUT/walk.log" | tail -5

echo "[$(date +%T)] queries bounded"
s=$(date +%s)
$PY $QUERIES bounded > "$OUT/queries.log" 2>&1
echo "[$(date +%T)] queries rc=$? seconds=$(( $(date +%s) - s ))"; tail -5 "$OUT/queries.log"

for t in hourly-trips brussels-arrivals airborne-hourly holding; do
  docker exec flights-kafka $KT/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
    --topic $t --from-beginning --timeout-ms 60000 > "$OUT/$t.json" 2>/dev/null
  echo "[$(date +%T)] $t: $(wc -l < "$OUT/$t.json") messages"
done
echo "[$(date +%T)] stop kafka"
