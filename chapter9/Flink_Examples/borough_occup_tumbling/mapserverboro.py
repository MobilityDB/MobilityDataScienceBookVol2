"""
mapserver.py  –  Live NYC Borough Bike-Trip Map
Consumes: Kafka topic 'boroughtumble' (live, no history replay)
Serves:   http://localhost:5001

Install:  pip install flask kafka-python
Run:      python mapserver.py
Stop:     Ctrl+C  (exits immediately)
"""

import json
import signal
import sys
import threading
from flask import Flask, jsonify, render_template_string
from kafka import KafkaConsumer, TopicPartition

KAFKA_BOOTSTRAP = "localhost:9092"
KAFKA_TOPIC     = "boroughtumble"
FLASK_PORT      = 5001

borough_state: dict = {}
state_lock  = threading.Lock()
stop_event  = threading.Event()

# ── Kafka thread ──────────────────────────────────────────────────────────────
def kafka_thread():
    try:
        print(f"[kafka] Connecting to {KAFKA_BOOTSTRAP} …")
        consumer = KafkaConsumer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            enable_auto_commit=False,
            value_deserializer=lambda b: json.loads(b.decode()) if b else None,
            key_deserializer=lambda b: json.loads(b.decode()) if b else None,
            consumer_timeout_ms=1000,   # unblocks every 1 s so we can check stop_event
            request_timeout_ms=30000,
        )
        # The topic exists once the Flink job writes its first window
        partitions = consumer.partitions_for_topic(KAFKA_TOPIC)
        while not partitions and not stop_event.is_set():
            print(f"[kafka] waiting for topic '{KAFKA_TOPIC}' …")
            stop_event.wait(2)
            consumer.close()
            consumer = KafkaConsumer(
                bootstrap_servers=KAFKA_BOOTSTRAP,
                enable_auto_commit=False,
                value_deserializer=lambda b: json.loads(b.decode()) if b else None,
                key_deserializer=lambda b: json.loads(b.decode()) if b else None,
                consumer_timeout_ms=1000,
                request_timeout_ms=30000,
            )
            partitions = consumer.partitions_for_topic(KAFKA_TOPIC)
        if not partitions:
            return
        tps = [TopicPartition(KAFKA_TOPIC, p) for p in partitions]
        consumer.assign(tps)
        consumer.seek_to_end(*tps)
        print(f"[kafka] Listening for new messages on {len(tps)} partition(s) …")

        while not stop_event.is_set():
            try:
                for msg in consumer:
                    if stop_event.is_set():
                        break
                    value = msg.value
                    key   = msg.key
                    if not value:
                        boroname = key.get("boroname") if isinstance(key, dict) else None
                        if boroname:
                            with state_lock:
                                borough_state.pop(boroname, None)
                        continue
                    boroname = value.get("boroname")
                    if not boroname:
                        continue
                    with state_lock:
                        borough_state[boroname] = value
                    print(f"[kafka] {boroname}: {value.get('total_trips')} trips  "
                          f"window={value.get('window_start')}")
            except StopIteration:
                pass  # consumer_timeout_ms expired — loop back and check stop_event

        consumer.close()
        print("[kafka] Consumer closed.")

    except Exception as e:
        print(f"[kafka] THREAD CRASHED: {e}")
        import traceback; traceback.print_exc()

# ── Signal handler — clean Ctrl+C ────────────────────────────────────────────
def handle_sigint(sig, frame):
    print("\n[main] Shutting down …")
    stop_event.set()
    sys.exit(0)

signal.signal(signal.SIGINT,  handle_sigint)
signal.signal(signal.SIGTERM, handle_sigint)

# ── Flask ─────────────────────────────────────────────────────────────────────
app = Flask(__name__)

HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>NYC Bike Borough Occupation – Live</title>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Arial, sans-serif; background: #1a1a2e; color: #eee; }
    #header {
      padding: 10px 16px; background: #16213e;
      display: flex; align-items: center; gap: 16px;
      border-bottom: 2px solid #0f3460;
    }
    #header h1 { font-size: 1.1rem; color: #e94560; }
    #status { font-size: 0.8rem; color: #aaa; margin-left: auto; }
    #map { height: calc(100vh - 46px); }
    .legend {
      background: rgba(22,33,62,0.9); border: 1px solid #0f3460;
      border-radius: 6px; padding: 10px 14px; color: #eee;
      font-size: 0.78rem; line-height: 1.8;
    }
    .legend-dot {
      display: inline-block; border-radius: 50%;
      background: rgba(233,69,96,0.7); border: 2px solid #e94560;
      vertical-align: middle; margin-right: 6px;
    }
    .leaflet-tooltip {
      background: #16213e; color: #eee;
      border: 1px solid #e94560; border-radius: 6px; font-size: 0.82rem;
    }
  </style>
</head>
<body>
<div id="header">
  <h1>NYC Citi Bike – Borough Occupation (live)</h1>
  <span id="status">Waiting for first window …</span>
</div>
<div id="map"></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css">
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
<script src="https://unpkg.com/@maplibre/maplibre-gl-leaflet@0.1.3/leaflet-maplibre-gl.js"></script>
<script>
const map = L.map("map").setView([40.73, -73.95], 11);
// The basemap: the OSM Shortbread vector tiles in the colors of the maps of the book (land,
// water, light buildings, white streets), drawn by MapLibre GL without labels
const STREETS = ["match", ["get", "kind"], ["motorway", "trunk", "primary"], 2.2,
  ["secondary", "tertiary"], 1.6, 0.9];
L.maplibreGL({ attribution: "Map data &copy; OpenStreetMap contributors", style: {
  version: 8,
  sources: { sb: { type: "vector", maxzoom: 14,
    tiles: ["https://vector.openstreetmap.org/shortbread_v1/{z}/{x}/{y}.mvt"] } },
  layers: [
    { id: "land", type: "background", paint: { "background-color": "#f2efe9" } },
    { id: "ocean", type: "fill", source: "sb", "source-layer": "ocean",
      paint: { "fill-color": "#aad3df" } },
    { id: "water", type: "fill", source: "sb", "source-layer": "water_polygons",
      paint: { "fill-color": "#aad3df" } },
    { id: "rivers", type: "line", source: "sb", "source-layer": "water_lines",
      paint: { "line-color": "#aad3df", "line-width": 1 } },
    { id: "piers", type: "fill", source: "sb", "source-layer": "pier_polygons",
      paint: { "fill-color": "#f2efe9" } },
    { id: "buildings", type: "fill", source: "sb", "source-layer": "buildings",
      paint: { "fill-color": "#d9d0c9" } },
    { id: "streets", type: "line", source: "sb", "source-layer": "streets",
      layout: { "line-cap": "round", "line-join": "round" },
      paint: { "line-color": "#ffffff", "line-width": STREETS } }] } }).addTo(map);

const circles = {};
const radius = t => Math.max(14, Math.sqrt(t) * 3.5);
const color  = t => t > 200 ? "#e94560" : t > 80 ? "#f4a261" : "#2ec4b6";

// The legend states the classes of color(); the area of a circle grows with its trips (radius()).
const legend = L.control({ position: "bottomright" });
legend.onAdd = () => {
  const div = L.DomUtil.create("div", "legend");
  const dot = t => `<span class="legend-dot" style="width:12px;height:12px;` +
    `background:${color(t)}73;border-color:${color(t)}"></span>`;
  div.innerHTML = `<b>Trips / window</b><br>
    ${dot(1)} 1–80<br>
    ${dot(81)} 81–200<br>
    ${dot(201)} over 200`;
  return div;
};
legend.addTo(map);
const fmt    = ts => (ts||"–").replace("T"," ").substring(0,19);

function updateMap(data) {
  Object.entries(data).forEach(([boro, r]) => {
    if (!r.latitude || !r.longitude) return;
    const tip = `<b>${boro}</b><br>Trips: <b>${r.total_trips}</b><br>
      ${fmt(r.window_start)} → ${fmt(r.window_end)}`;
    if (circles[boro]) {
      circles[boro]
        .setLatLng([r.latitude, r.longitude])
        .setRadius(radius(r.total_trips))
        .setStyle({ color: color(r.total_trips), fillColor: color(r.total_trips) })
        .setTooltipContent(tip);
    } else {
      circles[boro] = L.circleMarker([r.latitude, r.longitude], {
        radius: radius(r.total_trips), color: color(r.total_trips),
        fillColor: color(r.total_trips), fillOpacity: 0.45, weight: 2
      }).bindTooltip(tip, { sticky: true }).addTo(map);
    }
  });
  Object.keys(circles).forEach(b => {
    if (!data[b]) { map.removeLayer(circles[b]); delete circles[b]; }
  });
}

const statusEl = document.getElementById("status");
async function poll() {
  try {
    const data = await fetch("/api/boroughs").then(r => r.json());
    const n = Object.keys(data).length;
    statusEl.textContent = n
      ? `${new Date().toLocaleTimeString()} · ` +
        Object.entries(data).map(([b,v]) => `${b}: ${v.total_trips}`).join(" | ")
      : "Waiting for the next 30-second window from Flink …";
    updateMap(data);
  } catch(e) { statusEl.textContent = "Poll error"; }
}
poll();
setInterval(poll, 2000);
</script>
</body>
</html>"""

@app.route("/")
def index():
    return render_template_string(HTML)

@app.route("/api/boroughs")
def api_boroughs():
    with state_lock:
        return jsonify(dict(borough_state))

if __name__ == "__main__":
    threading.Thread(target=kafka_thread, daemon=True).start()
    print(f"[flask] http://localhost:{FLASK_PORT}  —  Ctrl+C to stop")
    app.run(host="0.0.0.0", port=FLASK_PORT, debug=False, threaded=True, use_reloader=False)

