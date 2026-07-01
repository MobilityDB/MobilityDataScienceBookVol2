"""
mapserver.py  –  HTTP server that serves:
  GET /          → dashboard_geofence.html
  GET /data      → latest geofence-counts from Kafka (JSON, polled every N seconds)
  GET /stream    → Server-Sent Events stream of geofence-counts in real time

Run:  python mapserver.py
Then open:  http://localhost:8888
"""

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from kafka import KafkaConsumer

# ---------------------------
# CONFIG
# ---------------------------
HTTP_HOST   = "localhost"
HTTP_PORT   = 8888
KAFKA_BROKERS = "localhost:9092"
KAFKA_TOPIC   = "geofence-counts"
KAFKA_GROUP   = "mapserver-group"

# ---------------------------
# SHARED STATE
# Kafka consumer thread writes here; HTTP handlers read it.
# ---------------------------
state_lock = threading.Lock()

# Latest known counts per zone, keyed by window key "start|end"
windows: dict = {}          # { "start|end": {"inside": N, "outside": N, "start": s, "end": e} }
latest_key: str = ""        # most recent window key
sse_clients: list = []      # open SSE response objects


def kafka_reader():
    """Background thread: reads geofence-counts forever, updates shared state."""
    global latest_key
    consumer = KafkaConsumer(
        KAFKA_TOPIC,
        bootstrap_servers=KAFKA_BROKERS,
        group_id=KAFKA_GROUP,
        auto_offset_reset="earliest",
        enable_auto_commit=True,
        value_deserializer=lambda b: json.loads(b.decode("utf-8")),
    )
    print(f"[kafka] connected, consuming '{KAFKA_TOPIC}'")
    for msg in consumer:
        data = msg.value
        # Expected keys: window_start, window_end, zone, total_trips
        ws  = data.get("window_start", "")
        we  = data.get("window_end",   "")
        zone = data.get("zone", "")
        trips = int(data.get("total_trips", 0))
        key = f"{ws}|{we}"

        with state_lock:
            if key not in windows:
                windows[key] = {"inside": 0, "outside": 0, "start": ws, "end": we}
            if zone == "INSIDE_MANHATTAN_ZONE":
                windows[key]["inside"] = trips
            else:
                windows[key]["outside"] = trips
            latest_key = key

            # Build SSE payload
            snapshot = _build_snapshot()

        # Push to all connected SSE clients
        push_sse(snapshot)


def _build_snapshot() -> dict:
    """Must be called with state_lock held."""
    if not latest_key or latest_key not in windows:
        return {}
    w = windows[latest_key]
    # Last 20 windows for history bars (sorted chronologically)
    history = sorted(windows.values(), key=lambda x: x["start"])[-20:]
    return {
        "inside":  w["inside"],
        "outside": w["outside"],
        "start":   w["start"],
        "end":     w["end"],
        "history": [{"start": h["start"], "inside": h["inside"]} for h in history],
    }


def push_sse(payload: dict):
    """Send an SSE event to every connected client."""
    if not payload:
        return
    line = "data: " + json.dumps(payload) + "\n\n"
    encoded = line.encode("utf-8")
    dead = []
    for client in sse_clients:
        try:
            client.wfile.write(encoded)
            client.wfile.flush()
        except Exception:
            dead.append(client)
    for d in dead:
        try:
            sse_clients.remove(d)
        except ValueError:
            pass


# ---------------------------
# HTTP HANDLER
# ---------------------------
DASHBOARD_FILE = Path(__file__).parent / "dashboard_geofence.html"

class Handler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        # Suppress per-request noise; only errors are printed
        if args and str(args[1]) not in ("200", "304"):
            print(f"[http] {self.path} → {args[1]}")

    def do_GET(self):
        path = self.path.split("?")[0]

        if path == "/" or path == "/dashboard_geofence.html":
            self._serve_file()
        elif path == "/data":
            self._serve_json()
        elif path == "/stream":
            self._serve_sse()
        else:
            self.send_error(404)

    def _serve_file(self):
        if not DASHBOARD_FILE.exists():
            self.send_error(404, "dashboard_geofence.html not found next to mapserver.py")
            return
        content = DASHBOARD_FILE.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def _serve_json(self):
        """One-shot JSON snapshot — for polling fallback."""
        with state_lock:
            payload = _build_snapshot()
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_sse(self):
        """Keep-alive SSE endpoint. Stays open until client disconnects."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        # Send current state immediately so the browser isn't blank
        with state_lock:
            payload = _build_snapshot()
            sse_clients.append(self)
        if payload:
            try:
                self.wfile.write(("data: " + json.dumps(payload) + "\n\n").encode())
                self.wfile.flush()
            except Exception:
                pass

        # Keep connection open — kafka_reader() will push new events
        try:
            while True:
                time.sleep(1)
                # Heartbeat comment keeps proxies from closing the connection
                self.wfile.write(b": heartbeat\n\n")
                self.wfile.flush()
        except Exception:
            pass
        finally:
            try:
                sse_clients.remove(self)
            except ValueError:
                pass


# ---------------------------
# ENTRY POINT
# ---------------------------
if __name__ == "__main__":
    t = threading.Thread(target=kafka_reader, daemon=True)
    t.start()

    server = HTTPServer((HTTP_HOST, HTTP_PORT), Handler)
    print(f"[server] http://{HTTP_HOST}:{HTTP_PORT}")
    print(f"[server] serving dashboard from {DASHBOARD_FILE}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] stopped")
