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

"""Replay the state vectors of March 1, 2026 into the Kafka topic flights-states, as if they were a
live feed of the OpenSky Network: each state vector becomes one JSON event, sent in the order of
its timestamp, and the replay sleeps between two events for their gap in event time divided by
SPEED, as replay_trips.py does for the Citi Bike trips.

The state vectors are those of the Parquet files that flights/fetch_data.sh downloads into
data/flights/parquet/hour=<Unix time of the hour>/, one file per hour, of which the replay keeps
the state vectors at every tenth second, the time step of the public CSV samples of the OpenSky
Network, as the flights tables of chapter 8 do. DuckDB reads each hour, sorts it by time, and
writes each state vector as JSON, under the names the book gives the columns (ICAO24, CallSign,
GeoAltitude): the column time of the files is sent as Et, since time is a reserved word of Flink
SQL. The day has 69
million state vectors at every tenth second, so the producer is that of confluent-kafka, a client
of the C library librdkafka, which sends about 300,000 events per second. At the default
speed-up of 20, the busiest hour of the day, 4.2 million state vectors, lasts three minutes, a
rate that the job FlightsWalk of the directory walk sustains on one task. Run from the directory
holding data/, as every example of this chapter.

    python replay_flights.py [SPEED]       # SPEED defaults to 20
"""
import glob
import sys
import time
from datetime import datetime, timezone

import duckdb
from confluent_kafka import Producer

TOPIC = "flights-states"
SPEED = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0
MIN_SLEEP, MAX_SLEEP = 0.0, 1.0

# One JSON event per state vector; DuckDB writes it, and a NULL column is a JSON null
EVENT = """
SELECT time, to_json({
    'ICAO24': icao24, 'Et': time, 'Lat': lat, 'Lon': lon, 'Velocity': velocity,
    'Heading': heading, 'VertRate': vertRate, 'CallSign': callsign, 'OnGround': onGround,
    'Alert': alert, 'SPI': spi, 'Squawk': squawk, 'BaroAltitude': baroAltitude,
    'GeoAltitude': geoAltitude, 'LastPosUpdate': lastPosUpdate,
    'LastContact': lastContact})::VARCHAR
FROM read_parquet(?)
WHERE time % 10 = 0
ORDER BY time
"""

producer = Producer({
    "bootstrap.servers": "localhost:9092",
    "compression.type": "lz4",
    "linger.ms": 20,
    "batch.size": 1024 * 1024,
    "queue.buffering.max.messages": 1_000_000})

files = sorted(glob.glob("data/flights/parquet/hour=*/*.parquet"))
print(f"Replaying {len(files)} hourly files into {TOPIC} at {SPEED:g} times the real speed")
con = duckdb.connect()
start, sent, prev_time = time.time(), 0, None
for path in files:
    cursor = con.execute(EVENT, [path])
    while batch := cursor.fetchmany(100_000):
        for event_time, event in batch:
            if prev_time is not None and event_time != prev_time:
                delta = event_time - prev_time
                time.sleep(min(max(delta / SPEED, MIN_SLEEP), MAX_SLEEP))
            while True:
                try:
                    producer.produce(TOPIC, event.encode("utf-8"))
                    break
                except BufferError:  # the local queue is full: wait for the broker
                    producer.poll(0.1)
            producer.poll(0)
            prev_time = event_time
            sent += 1
    print(f"Sent {sent} up to {datetime.fromtimestamp(prev_time, timezone.utc):%H:%M:%S} "
          f"after {time.time() - start:.0f} s", flush=True)

producer.flush()
print(f"Replay finished: {sent} state vectors in {time.time() - start:.0f} s.")
