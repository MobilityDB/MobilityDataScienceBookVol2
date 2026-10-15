#!/bin/bash
# Run the four Citi Bike dashboards of the chapter as the README of the chapter runs them, one
# Kafka broker at a time, and print each to a PDF with capture.py. Each run replays the trips of
# the day that start before a cutoff instant, so that the last windows Flink fires are those the
# figure shows, and the dashboard holds them when the page opens. Its helpers are one bash
# function per step with their arguments in a trailing comment, as #sql of citibike/build.sh and
# #fetch of citibike/fetch_data.sh.
#
#   bash citibike_dashboards.sh <example> ...      example: top10 | geofence | boro | slidejoin
#
# The trips and the stations are read from $DATA/citibike/flink (default: data below the working
# directory), which the pipeline of the directory citibike exports. Each run works in
# $OUT/run/<example> and writes $OUT/<example>.pdf and its PNG preview (default: out below the
# working directory). PYTHON is the Python with PyFlink, kafka-python, flask and Playwright
# (default: python3). The Kafka broker runs in the Docker container $KAFKA (default:
# citibike-kafka) on port 9092. SLIDEJOIN_CUTOFF overrides the cutoff of the join example.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
EX=$(cd "$HERE/../Flink_Examples" && pwd)
PY=${PYTHON:-python3}
FLINK=$(cd "${DATA:-$PWD/data}/citibike/flink" && pwd)
OUT=$(mkdir -p "${OUT:-$PWD/out}" && cd "${OUT:-$PWD/out}" && pwd)
KAFKA=${KAFKA:-citibike-kafka}
SHOTS=$OUT
# The JVM of each PyFlink job stays within 2 GB.
export JAVA_TOOL_OPTIONS=-Xmx2g
mkdir -p $SHOTS $OUT/run

cut_data() { # dir cutoff: the trips of the export that start before cutoff, and the stations
  mkdir -p $1/data/citibike/flink/trips $1/data/citibike/flink/stations
  awk -F'\t' -v c="$2" '$3 < c' $FLINK/trips/part-*.csv > $1/data/citibike/flink/trips/part-00000.csv
  cp $FLINK/stations/part-*.csv $1/data/citibike/flink/stations/part-00000.csv
  echo "trips before $2: $(wc -l < $1/data/citibike/flink/trips/part-00000.csv)"
}

kafka_up() { # topics...
  docker run -d --name $KAFKA -p 9092:9092 -e KAFKA_HEAP_OPTS="-Xmx512m -Xms512m" apache/kafka:3.9.1 > /dev/null
  until docker exec $KAFKA /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do sleep 2; done
  for t in "$@"; do
    docker exec $KAFKA /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
      --create --if-not-exists --topic $t --partitions 1 > /dev/null
  done
}

kafka_down() { docker rm -f $KAFKA > /dev/null 2>&1; }

run() { # name cutoff job server page_url condition width height producers...
  local name=$1 cutoff=$2 job=$3 server=$4 url=$5 cond=$6 width=$7 height=$8; shift 8
  local dir=$OUT/run/$name pids=()
  rm -rf $dir; cut_data $dir "$cutoff"
  cd $dir
  $PY $EX/$job > $dir/job.log 2>&1 & pids+=($!)
  sleep 25
  $PY $EX/$server > $dir/server.log 2>&1 & pids+=($!)
  sleep 5
  # LIVE=1: the page is open while the producers replay, so its counters count the stream; the
  # capture waits for the condition, which holds from the last windows of the replay on
  local prods=() cap=
  if [ "${LIVE:-0}" = 1 ]; then
    $PY $HERE/capture.py "$url" $SHOTS/$name.pdf $width $height "$cond" 40 600 > $dir/capture.log 2>&1 & cap=$!
    sleep 15
  fi
  for p in "$@"; do $PY $EX/$p 2000 > $dir/$(basename $p .py).log 2>&1 & prods+=($!); done
  wait "${prods[@]}"
  sleep 40
  for t in $(docker exec $KAFKA /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list); do
    echo "topic $t: $(docker exec $KAFKA /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic $t 2>/dev/null | tr '\n' ' ')"
  done > $dir/topics.log
  if [ -n "$cap" ]; then wait $cap; else
    $PY $HERE/capture.py "$url" $SHOTS/$name.pdf $width $height "$cond" 25 300 > $dir/capture.log 2>&1
  fi
  echo "$name capture rc=$? $(head -3 $dir/capture.log)"
  kill "${pids[@]}" 2> /dev/null; sleep 3; kill -9 "${pids[@]}" 2> /dev/null
  pkill -f "$EX/$job" 2> /dev/null
  cd $OUT
}

BASE="document.querySelector('canvas.maplibregl-canvas') !== null"
for ex in "$@"; do
  kafka_down
  case $ex in
    top10)
      kafka_up raw-trips
      run top10 "2023-09-20 08:49:05" TopNSlideWEventTime/topneventsliding.py \
        TopNSlideWEventTime/mapservertopn.py http://localhost:5000/ \
        "$BASE && document.getElementById('window').textContent.includes('08:48:15')" 1200 800 \
        replay_trips.py ;;
    geofence)
      kafka_up raw-trips
      LIVE=1 run geofence "2023-09-20 11:30:00" Geofencing/flink_eventtime_geofence.py \
        Geofencing/mapserver_geofence.py http://localhost:8888/ \
        "$BASE && document.getElementById('ws').textContent.includes('11:20:00')" 1385 802 \
        replay_trips.py ;;
    boro)
      kafka_up raw-trips
      run boro "2023-09-20 11:17:30" borough_occup_tumbling/boroughoccupationevent.py \
        borough_occup_tumbling/mapserverboro.py http://localhost:5001/ \
        "$BASE && !document.getElementById('status').textContent.includes('Waiting')" 1487 834 \
        replay_trips.py ;;
    slidejoin)
      kafka_up trip-starts trip-ends
      run slidejoin "${SLIDEJOIN_CUTOFF:-2023-09-20 08:30:00}" join_two_streams/stationbalance.py \
        join_two_streams/mapserver-stationbalance.py http://localhost:5050/ \
        "$BASE && document.querySelectorAll('.leaflet-interactive').length > 0" 1270 813 \
        join_two_streams/producerstationstart.py join_two_streams/producerstationend.py ;;
  esac
  kafka_down
done
