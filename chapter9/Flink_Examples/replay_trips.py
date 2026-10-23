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

"""Replay the Citi Bike trips of one day into the Kafka topic raw-trips, as if they were a live
feed: each trip becomes one JSON event at its start, and the replay sleeps between two events for
their gap in event time divided by SPEED.

The trips are those that citibike/build.sh exports into data/citibike/flink/trips, one line per
trip in the order of its start, with the columns of the trips table of the book (see the appendix
on the Citi Bike data). Run from the directory holding data/, as every example of this chapter.

    python replay_trips.py [SPEED]       # SPEED defaults to 2000
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
MIN_SLEEP, MAX_SLEEP = 0.0, 1.0

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    linger_ms=5)

rows = []
for path in sorted(glob.glob("data/citibike/flink/trips/*.csv")):
    with open(path, encoding="utf-8") as f:
        for values in csv.reader(f, delimiter="\t"):
            row = dict(zip(COLUMNS, values))
            rows.append((datetime.strptime(row["started_at"], "%Y-%m-%d %H:%M:%S"), row))
print(f"Loaded {len(rows)} trips from {rows[0][0]} to {rows[-1][0]}")

prev_time = None
for i, (event_time, row) in enumerate(rows):
    producer.send("raw-trips", {
        "start_station_id": row["start_station_id"],
        "start_station_name": row["start_station_name"],
        "end_station_name": row["end_station_name"],
        "start_time": event_time.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]})
    if i % 10000 == 0:
        print(f"Sent {i} ({event_time})")
    if prev_time is not None:
        delta = (event_time - prev_time).total_seconds()
        time.sleep(min(max(delta / SPEED, MIN_SLEEP), MAX_SLEEP))
    prev_time = event_time

producer.flush()
producer.close()
print("Replay finished.")
