import csv
import json
import time
from kafka import KafkaProducer
from datetime import datetime

INPUT_FILE = "/mnt/e/Data/NYCBikes/tripsny.tsv"

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    linger_ms=5
)

# ---------------------------
# LOAD DATA (full dataset, no date filter)
# ---------------------------
rows = []
with open(INPUT_FILE, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        if not row.get("start_time"):
            continue
        try:
            t = datetime.strptime(row["start_time"], "%Y-%m-%d %H:%M:%S")
        except:
            continue
        rows.append((t, row))

rows.sort(key=lambda x: x[0])
print(f"Loaded {len(rows)} trips total")
print(f"Date range: {rows[0][0]} to {rows[-1][0]}")

# ---------------------------
# CONFIG
# ---------------------------
SPEED = 2000.0
MIN_SLEEP = 0.02
MAX_SLEEP = 1.0

# ---------------------------
# STREAM REPLAY
# ---------------------------
prev_time = None
for i, (event_time, row) in enumerate(rows):
    msg = {
        "start_station_id": row["start_station_id"],
        "start_station_name": row["start_station_name"],
        "end_station_name": row["end_station_name"],
        "start_time": event_time.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
    }
    print("ABOUT TO SEND")
    producer.send("raw_trips", msg)
    print("SENT CALL RETURNED")


    if i % 1000 == 0:
        print(f"Sent {i} ({event_time})")

    if prev_time is not None:
        delta = (event_time - prev_time).total_seconds()
        sleep_time = min(max(delta / SPEED, MIN_SLEEP), MAX_SLEEP)
        time.sleep(sleep_time)
    prev_time = event_time

producer.flush()
producer.close()
print("Replay finished.")
