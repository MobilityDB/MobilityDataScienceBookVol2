"""Producer A of the station-balance example: replay the trip starts of one day into the
Kafka topic trip-starts, one JSON event per trip at its start, with the station and its
coordinates. The trips are those that citibike/build.sh exports into data/citibike/flink/trips
(see the appendix on the Citi Bike data); run from the directory holding data/. The replay
sleeps between two events for their gap in event time divided by SPEED, as replay_trips.py.

    python producerstationstart.py [SPEED]       # SPEED defaults to 2000
"""
import csv
import glob
import json
import sys
import time
from datetime import datetime

from kafka import KafkaProducer

COLUMNS = ["ride_id", "rideable_type", "started_at", "ended_at", "start_station_id",
           "start_station_name", "end_station_id", "end_station_name", "start_lat",
           "start_lng", "end_lat", "end_lng", "member_casual"]
SPEED = float(sys.argv[1]) if len(sys.argv) > 1 else 2000.0

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8"))

rows = []
for path in sorted(glob.glob("data/citibike/flink/trips/*.csv")):
    with open(path, encoding="utf-8") as f:
        for values in csv.reader(f, delimiter="\t"):
            row = dict(zip(COLUMNS, values))
            if row["start_station_name"]:
                rows.append((datetime.strptime(row["started_at"], "%Y-%m-%d %H:%M:%S"), row))
rows.sort(key=lambda x: x[0])

prev_time = None
for t, row in rows:
    producer.send("trip-starts", {
        "station": row["start_station_name"],
        "lat": float(row["start_lat"]),
        "lon": float(row["start_lng"]),
        "event_time": t.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]})
    if prev_time is not None:
        time.sleep(min((t - prev_time).total_seconds() / SPEED, 1.0))
    prev_time = t

producer.flush()
producer.close()
