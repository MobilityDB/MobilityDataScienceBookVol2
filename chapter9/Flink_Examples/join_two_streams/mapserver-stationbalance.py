"""
mapserver-stationbalance.py
---------------------------
Real-time map server for Citi Bike NYC.
Consumes the Kafka topic 'station-balance' and serves a map
where each station is green (more returns) or red (more pick-ups).

The coordinates come from the topic itself, with no other source.

Dependencies:
    pip install flask kafka-python

Usage:
    python mapserver-stationbalance.py
    Open http://localhost:5050
"""

import json
import threading

from flask import Flask, Response, render_template_string
from kafka import KafkaConsumer

# ── Config ────────────────────────────────────────────────────────────────────

KAFKA_BOOTSTRAP = "localhost:9092"
TOPIC           = "station-balance"
GROUP_ID        = "map-server"
FLASK_PORT      = 5050

# ── Shared state ─────────────────────────────────────────────────────────

station_data: dict[str, dict] = {}
data_lock    = threading.Lock()
sse_clients: list = []
clients_lock = threading.Lock()

# ── Kafka consumer (background thread) ────────────────────────────────────────────

def kafka_consumer_thread():
    consumer = KafkaConsumer(
        TOPIC,
        bootstrap_servers=KAFKA_BOOTSTRAP,
        group_id=GROUP_ID,
        auto_offset_reset="earliest",
        value_deserializer=lambda b: json.loads(b.decode("utf-8")),
        enable_auto_commit=True,
    )

    print(f"[Kafka] Connected to '{TOPIC}'")

    for msg in consumer:
        val = msg.value
        station    = val.get("station", "")
        departures = int(val.get("departures", 0))
        arrivals   = int(val.get("arrivals",   0))
        lat        = val.get("lat")
        lon        = val.get("lon")

        if not station or lat is None or lon is None:
            continue

        entry = {
            "departures": departures,
            "arrivals":   arrivals,
            "lat":        float(lat),
            "lon":        float(lon),
        }

        with data_lock:
            station_data[station] = entry

        payload = json.dumps({"station": station, **entry})

        dead = []
        with clients_lock:
            for q in sse_clients:
                try:
                    q.append(payload)
                except Exception:
                    dead.append(q)
            for q in dead:
                sse_clients.remove(q)


# ── Flask app ─────────────────────────────────────────────────────────────────

app = Flask(__name__)

HTML = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Citi Bike · Station balance</title>
<meta name="viewport" content="width=device-width, initial-scale=1">

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">

<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:        #0f1117;
    --surface:   #181c27;
    --border:    #252a38;
    --text:      #e8ecf4;
    --muted:     #6b7591;
    --green:     #22c97a;
    --red:       #f2415a;
    --neutral:   #8892b0;
    --accent:    #3d7eff;
    --font-ui:   'Inter', system-ui, sans-serif;
    --font-mono: 'DM Mono', monospace;
  }

  html, body { height: 100%; background: var(--bg); color: var(--text); font-family: var(--font-ui); }

  #app {
    display: grid;
    grid-template-rows: 52px 1fr;
    grid-template-columns: 300px 1fr;
    height: 100vh;
  }

  /* ── Header ── */
  header {
    grid-column: 1 / -1;
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 0 20px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    z-index: 10;
  }
  header .logo  { font-family: var(--font-mono); font-weight: 500; font-size: 13px; letter-spacing: .08em; text-transform: uppercase; color: var(--accent); }
  header .title { font-size: 14px; font-weight: 600; color: var(--text); }
  header .pill  { margin-left: auto; display: flex; align-items: center; gap: 6px; font-family: var(--font-mono); font-size: 11px; color: var(--muted); }
  header .pulse { width: 7px; height: 7px; border-radius: 50%; background: var(--green); animation: pulse 1.8s ease infinite; }
  @keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }

  /* ── Sidebar ── */
  #sidebar {
    background: var(--surface);
    border-right: 1px solid var(--border);
    overflow-y: auto;
    display: flex;
    flex-direction: column;
  }
  #sidebar::-webkit-scrollbar { width: 4px; }
  #sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

  .sidebar-head {
    padding: 14px 16px 10px;
    font-size: 11px;
    font-family: var(--font-mono);
    letter-spacing: .1em;
    text-transform: uppercase;
    color: var(--muted);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0;
    background: var(--surface);
    z-index: 1;
  }

  #station-list { flex: 1; padding: 6px 0; }

  .station-item {
    display: flex; align-items: center; gap: 10px;
    padding: 8px 16px;
    cursor: pointer;
    transition: background .12s;
    border-left: 3px solid transparent;
  }
  .station-item:hover { background: rgba(255,255,255,.04); }
  .station-item.active { background: rgba(61,126,255,.08); border-left-color: var(--accent); }

  .dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
  .dot.green   { background: var(--green); }
  .dot.red     { background: var(--red); }
  .dot.neutral { background: var(--neutral); }

  .station-name  { font-size: 12px; font-weight: 500; color: var(--text); flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .station-delta { font-family: var(--font-mono); font-size: 11px; }
  .station-delta.pos { color: var(--green); }
  .station-delta.neg { color: var(--red); }
  .station-delta.neu { color: var(--neutral); }

  /* ── Map ── */
  #map { z-index: 0; }

  /* ── Legend ── */
  #legend {
    position: absolute; bottom: 28px; right: 16px; z-index: 900;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 12px 16px;
    font-size: 12px; display: flex; flex-direction: column; gap: 7px;
    pointer-events: none;
  }
  .legend-row { display: flex; align-items: center; gap: 8px; color: var(--muted); }
  .legend-dot { width: 10px; height: 10px; border-radius: 50%; }

  /* ── Popup ── */
  .leaflet-popup-content-wrapper {
    background: var(--surface) !important; border: 1px solid var(--border) !important;
    border-radius: 8px !important; box-shadow: 0 8px 32px rgba(0,0,0,.5) !important;
    color: var(--text) !important; font-family: var(--font-ui) !important;
  }
  .leaflet-popup-tip { background: var(--surface) !important; }
  .leaflet-popup-close-button { color: var(--muted) !important; }
  .popup-station { font-size: 13px; font-weight: 600; margin-bottom: 10px; }
  .popup-row     { display: flex; justify-content: space-between; gap: 24px; font-size: 12px; margin-bottom: 4px; }
  .popup-label   { color: var(--muted); }
  .popup-val     { font-family: var(--font-mono); font-weight: 500; }
  .popup-delta   { font-family: var(--font-mono); font-size: 13px; font-weight: 600; margin-top: 8px; }
</style>
</head>
<body>
<div id="app">

  <header>
    <span class="logo">CitiBike</span>
    <span class="title">Station balance · real time</span>
    <div class="pill">
      <div class="pulse"></div>
      <span id="status-text">conectando…</span>
    </div>
  </header>

  <div id="sidebar">
    <div class="sidebar-head">Active stations</div>
    <div id="station-list"></div>
  </div>

  <div id="map"></div>

</div>

<div id="legend">
  <div class="legend-row"><div class="legend-dot" style="background:#22c97a"></div>More returns than pick-ups</div>
  <div class="legend-row"><div class="legend-dot" style="background:#f2415a"></div>More pick-ups than returns</div>
  <div class="legend-row"><div class="legend-dot" style="background:#8892b0"></div>Balanced</div>
</div>

<script>
const map = L.map('map', { center: [40.730, -73.990], zoom: 13, zoomControl: true });

L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}', {
  attribution: 'Tiles &copy; Esri &mdash; Esri, HERE, Garmin, &copy; OpenStreetMap contributors', maxZoom: 16
}).addTo(map);
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}', { maxZoom: 16 }).addTo(map);

const stations   = {};
let   activeItem = null;

function colorFor(dep, arr) {
  if (dep > arr) return '#f2415a';
  if (arr > dep) return '#22c97a';
  return '#8892b0';
}
function dotClass(dep, arr) {
  if (dep > arr) return 'red';
  if (arr > dep) return 'green';
  return 'neutral';
}
function deltaText(dep, arr) {
  const d = arr - dep;
  return d > 0 ? `+${d}` : d < 0 ? `${d}` : '±0';
}
function deltaClass(dep, arr) {
  if (arr > dep) return 'pos';
  if (dep > arr) return 'neg';
  return 'neu';
}
function makeCircle(lat, lon, color) {
  return L.circleMarker([lat, lon], {
    radius: 9, color, fillColor: color, fillOpacity: 0.85, weight: 2,
  });
}
function popupHTML(name, dep, arr) {
  const d = arr - dep;
  const color = colorFor(dep, arr);
  const sign  = d >= 0 ? '+' : '';
  return `
    <div class="popup-station">${name}</div>
    <div class="popup-row"><span class="popup-label">Pick-ups</span><span class="popup-val">${dep}</span></div>
    <div class="popup-row"><span class="popup-label">Returns</span><span class="popup-val">${arr}</span></div>
    <div class="popup-delta" style="color:${color}">Balance ${sign}${d}</div>
  `;
}

const listEl   = document.getElementById('station-list');
const statusEl = document.getElementById('status-text');
let   count    = 0;

function upsertSidebarItem(name, dep, arr) {
  const id = 'si-' + CSS.escape(name);
  let el = document.getElementById(id);
  if (!el) {
    el = document.createElement('div');
    el.id = id;
    el.className = 'station-item';
    el.innerHTML = `
      <div class="dot ${dotClass(dep,arr)}"></div>
      <div class="station-name" title="${name}">${name}</div>
      <div class="station-delta ${deltaClass(dep,arr)}">${deltaText(dep,arr)}</div>
    `;
    el.addEventListener('click', () => {
      const s = stations[name];
      if (!s) return;
      map.setView([s.lat, s.lon], 15);
      s.marker.openPopup();
      if (activeItem) activeItem.classList.remove('active');
      el.classList.add('active');
      activeItem = el;
    });
    listEl.appendChild(el);
  } else {
    el.querySelector('.dot').className          = `dot ${dotClass(dep,arr)}`;
    el.querySelector('.station-delta').className = `station-delta ${deltaClass(dep,arr)}`;
    el.querySelector('.station-delta').textContent = deltaText(dep,arr);
  }
}

function applyUpdate(d) {
  const { station, departures, arrivals, lat, lon } = d;
  const color = colorFor(departures, arrivals);

  if (stations[station]) {
    const s = stations[station];
    s.departures = departures;
    s.arrivals   = arrivals;
    s.marker.setStyle({ color, fillColor: color });
    s.marker.setPopupContent(popupHTML(station, departures, arrivals));
  } else {
    const marker = makeCircle(lat, lon, color).addTo(map);
    marker.bindPopup(popupHTML(station, departures, arrivals), { maxWidth: 220 });
    marker.on('click', () => {
      const el = document.getElementById('si-' + CSS.escape(station));
      if (activeItem) activeItem.classList.remove('active');
      if (el) { el.classList.add('active'); activeItem = el; }
    });
    stations[station] = { marker, departures, arrivals, lat, lon };
    count++;
    statusEl.textContent = `live · ${count} stations`;
  }

  upsertSidebarItem(station, departures, arrivals);
}

function connect() {
  const es = new EventSource('/stream');
  es.onopen  = () => { statusEl.textContent = 'live'; };
  es.onerror = () => { statusEl.textContent = 'reconectando…'; es.close(); setTimeout(connect, 3000); };

  es.addEventListener('snapshot', e => {
    JSON.parse(e.data).forEach(applyUpdate);
    statusEl.textContent = `live · ${count} stations`;
  });
  es.addEventListener('station', e => { applyUpdate(JSON.parse(e.data)); });
}

connect();
</script>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(HTML)


@app.route("/stream")
def stream():
    client_queue: list[str] = []
    with clients_lock:
        sse_clients.append(client_queue)

    def generate():
        with data_lock:
            snapshot = [{"station": k, **v} for k, v in station_data.items()]
        if snapshot:
            yield f"event: snapshot\ndata: {json.dumps(snapshot)}\n\n"

        import time
        try:
            while True:
                if client_queue:
                    yield f"event: station\ndata: {client_queue.pop(0)}\n\n"
                else:
                    yield ": heartbeat\n\n"
                    time.sleep(0.5)
        except GeneratorExit:
            with clients_lock:
                if client_queue in sse_clients:
                    sse_clients.remove(client_queue)

    return Response(generate(), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


if __name__ == "__main__":
    t = threading.Thread(target=kafka_consumer_thread, daemon=True)
    t.start()
    print(f"Map available at http://localhost:{FLASK_PORT}")
    app.run(host="0.0.0.0", port=FLASK_PORT, threaded=True)
