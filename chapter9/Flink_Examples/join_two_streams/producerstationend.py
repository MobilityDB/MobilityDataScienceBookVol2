import csv
import json
import time
from kafka import KafkaProducer
from datetime import datetime

INPUT_FILE = "/mnt/e/Data/NYCBikes/tripsny.tsv"

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

rows = []

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        try:
            t = datetime.strptime(
                row["stop_time"],
                "%Y-%m-%d %H:%M:%S"
            )
        except:
            continue

        rows.append((t, row))

rows.sort(key=lambda x: x[0])

for t, row in rows:

    producer.send(
        "trip-ends",
        {
            "station": row["end_station_name"],
            "event_time": t.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
        }
    )

    time.sleep(0.01)

producer.flush()
