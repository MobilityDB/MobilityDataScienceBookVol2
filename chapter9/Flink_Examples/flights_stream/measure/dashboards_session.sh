#!/bin/bash
# One bounded measuring session of the air traffic stream: start Kafka, replay the day at full
# speed, run the walk and then the dashboards job over the topics up to their end, timing each,
# and compare the topics with the answers of MobilityDB with compare.py, then stop Kafka.
#
#   bash dashboards_session.sh <out>
#
# Run it from the directory that holds data/ (the Parquet day that flights/fetch_data.sh
# downloads) and src/libmeos.so, from which JMEOS loads MEOS, after building the walk as the
# README of the chapter builds it and exporting the answers of MobilityDB with
# export_baseline.sql into $BASELINE (default: baseline below the working directory). MEOS_LIB is
# the directory of the libmeos.so that MobilityFlink built and PYTHON the Python with PyFlink,
# confluent-kafka, kafka-python and duckdb (default: python3). The Kafka broker runs in the
# Docker container flights-kafka on port 9092. The logs of the steps, the dumps of the topics
# and summary.json are written into <out>.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
EX=$(cd "$HERE/.." && pwd)
OUT=$(mkdir -p "${1:?out}" && cd "$1" && pwd)
BASELINE=$(cd "${BASELINE:-$PWD/baseline}" && pwd)
PY=${PYTHON:-python3}
PYLIB=$($PY -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
WALKCP="$PYLIB/*:$EX/walk/target/flights-walk-1.0.jar:$EX/walk/target/lib/*"
export MOBILITYFLINK_JARS=$(ls $EX/walk/target/lib/*.jar | tr '\n' ';' | sed 's/;$//')
export JVM_ARGS="-Xmx1200m"
export LD_LIBRARY_PATH=${MEOS_LIB:?directory of libmeos.so}
JAVA_OPENS="--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED"
trap 'docker rm -f flights-kafka >/dev/null 2>&1' EXIT

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

echo "[$(date +%T)] replay at full speed"
s=$(date +%s)
$PY $EX/replay_flights.py 1e12 > "$OUT/replay.log" 2>&1
echo "[$(date +%T)] replay rc=$? seconds=$(( $(date +%s) - s ))"; tail -2 "$OUT/replay.log"

echo "[$(date +%T)] walk bounded"
s=$(date +%s)
java -Xmx1200m $JAVA_OPENS -cp "$WALKCP" flights.FlightsWalk bounded > "$OUT/walk.log" 2>&1
echo "[$(date +%T)] walk rc=$? seconds=$(( $(date +%s) - s ))"
grep -v '^Running on\|library path\|Loading library' "$OUT/walk.log" | tail -5

echo "[$(date +%T)] dashboards bounded"
s=$(date +%s)
$PY $EX/flights_dashboards.py bounded > "$OUT/dashboards.log" 2>&1
echo "[$(date +%T)] dashboards rc=$? seconds=$(( $(date +%s) - s ))"; tail -5 "$OUT/dashboards.log"

echo "[$(date +%T)] compare"
$PY $HERE/compare.py "$OUT" "$BASELINE" > "$OUT/compare.log" 2>&1
echo "[$(date +%T)] compare rc=$?"; head -80 "$OUT/compare.log"
free -g | head -2
echo "[$(date +%T)] stop kafka"
