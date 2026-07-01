"""
Citi Bike Top-10 live map server.

Tails the 'top-stations-event' upsert-kafka topic produced by the PyFlink
sliding-window job and pushes live updates to a browser-based Leaflet map
+ leaderboard via Server-Sent Events (SSE).

Setup (in your WSL environment, same place the producer/Flink job run):

    pip install flask kafka-python --break-system-packages

Run:

    python server.py

Then open http://localhost:5000 in a browser (Kafka, the producer, and the
Flink job should already be running and writing to 'top-stations-event').
"""

import json
import queue
import threading
import time

from flask import Flask, Response, render_template
from kafka import KafkaConsumer

KAFKA_BOOTSTRAP_SERVERS = "localhost:9092"
TOPIC = "top-stations-event"

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Shared state (protected by state_lock)
# ---------------------------------------------------------------------------
state_lock = threading.Lock()
current_window = None   # (window_start, window_end) as strings, or None
current_top = {}        # rank_num -> station dict
subscribers = []        # one queue.Queue per connected browser tab


def _snapshot():
    """Return a JSON-serializable snapshot of the current top-N state."""
    with state_lock:
        stations = sorted(current_top.values(), key=lambda s: s["rank_num"])
        window_start, window_end = current_window if current_window else (None, None)
    return {
        "window_start": window_start,
        "window_end": window_end,
        "stations": stations,
    }


def _broadcast():
    payload = json.dumps(_snapshot())
    for q in list(subscribers):
        q.put(payload)


def _kafka_consumer_loop():
    """Background thread: tail the top-stations-event topic forever."""
    global current_window, current_top

    while True:
        try:
            consumer = KafkaConsumer(
                TOPIC,
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                auto_offset_reset="earliest",
                enable_auto_commit=False,
                group_id=None,
                value_deserializer=lambda v: json.loads(v.decode("utf-8")) if v else None,
                key_deserializer=lambda k: json.loads(k.decode("utf-8")) if k else None,
            )
            print(f"[kafka] connected, tailing topic '{TOPIC}'")

            for msg in consumer:
                value = msg.value
                key = msg.key

                if value is None:
                    # upsert-kafka emits a tombstone (null value) when a
                    # previously produced (window, rank) key is retracted.
                    if key is not None:
                        win = (key.get("window_start"), key.get("window_end"))
                        rank = key.get("rank_num")
                        with state_lock:
                            if win == current_window:
                                current_top.pop(rank, None)
                    _broadcast()
                    continue

                win = (value["window_start"], value["window_end"])
                with state_lock:
                    if win != current_window:
                        # New sliding window started - drop the old top-10.
                        current_window = win
                        current_top = {}
                    current_top[value["rank_num"]] = value
                _broadcast()

        except Exception as exc:
            print(f"[kafka] consumer error: {exc!r} - retrying in 5s")
            time.sleep(5)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/events")
def events():
    def stream():
        q = queue.Queue()
        subscribers.append(q)
        try:
            # Send current state immediately so a new tab isn't blank while
            # waiting for the next sliding window to fire.
            yield f"data: {json.dumps(_snapshot())}\n\n"
            while True:
                payload = q.get()
                yield f"data: {payload}\n\n"
        finally:
            subscribers.remove(q)

    return Response(stream(), mimetype="text/event-stream")


if __name__ == "__main__":
    t = threading.Thread(target=_kafka_consumer_loop, daemon=True)
    t.start()
    app.run(host="0.0.0.0", port=5000, threaded=True, debug=False)

