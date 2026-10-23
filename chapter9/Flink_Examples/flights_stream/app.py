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

"""The three dashboards of the air traffic use case of chapter 9, in Streamlit over the output
topics of the Flink jobs of this directory, read directly from Kafka, without a database in
between.

A consumer of Kafka, in a thread of the app, reads the topics climbing-brussels (dashboard 1, one
row per position of a flight climbing over Brussels), close-pairs (dashboard 2, one row per pair
of airborne aircraft within one kilometer of each other in a window of ten minutes) and
traffic-per-hour (dashboard 3, one row per hour), which flights_dashboards.py writes, and keeps
their rows in memory: all the rows of dashboards 1 and 3, and those of the recent windows of
dashboard 2. The reader is #kafka_reader of Geofencing/mapserver_geofence.py. The page redraws
its maps and charts every few seconds as new rows arrive. The maps are pydeck layers, drawn by
viridis and map_chart as the dashboards of chapter 8 (chapter8/dashboards/app.py) draw theirs,
whose panels these follow, over the OSM Shortbread vector tiles in the colors of the maps of the
book, as the basemap of Geofencing/dashboard_geofence.html: the style static/shortbread.json,
which the app serves itself.

    streamlit run app.py --server.enableStaticServing true --theme.base light \
        --client.toolbarMode viewer
"""
import json
import threading
from collections import deque

import numpy as np
import pandas as pd
import pydeck as pdk
import streamlit as st
from kafka import KafkaConsumer

KAFKA_BROKERS = "localhost:9092"
TOPICS = ["climbing-brussels", "close-pairs", "traffic-per-hour"]
RECENT_WINDOWS = 18  # the windows of ten minutes of dashboard 2 kept in memory: three hours
REFRESH = 5  # seconds between two redraws of the page
VIRIDIS = np.array([[68, 1, 84], [59, 82, 139], [33, 145, 140], [94, 201, 98], [253, 231, 37]])
# The base map: a MapLibre style over the OSM Shortbread vector tiles, served by the app
BASE_MAP = f"http://localhost:{st.get_option('server.port')}/app/static/shortbread.json"

st.set_page_config(page_title="Air traffic over Europe as a stream", layout="wide")


# ------------------------------------------------------------------------------- Kafka
class Rows:
    """The rows of the three topics, filled by the consumer thread and read by the page."""

    def __init__(self):
        self.lock = threading.Lock()
        self.climbing = []
        self.pairs = {}  # the pairs of each recent window of ten minutes, by its start
        self.windows = deque()
        self.pair_counts = {}  # the number of pairs and the smallest distance per window
        self.closest = None  # the pair of the smallest distance so far
        self.hours = {}
        self.messages = 0

    def add(self, topic, row):
        with self.lock:
            self.messages += 1
            if topic == "climbing-brussels":
                self.climbing.append(row)
            elif topic == "close-pairs":
                start = row["window_start"]
                if start not in self.pair_counts:
                    self.pairs[start] = []
                    self.windows.append(start)
                    while len(self.windows) > RECENT_WINDOWS:
                        self.pairs.pop(self.windows.popleft(), None)
                if start in self.pairs:
                    self.pairs[start].append(row)
                n, d = self.pair_counts.get(start, (0, float("inf")))
                self.pair_counts[start] = (n + 1, min(d, row["distance"]))
                if self.closest is None or row["distance"] < self.closest["distance"]:
                    self.closest = row
            else:
                self.hours[row["window_start"]] = row

    def snapshot(self):
        """A copy of the rows, for the page to draw while the thread goes on."""
        with self.lock:
            copy = Rows()
            copy.climbing = list(self.climbing)
            copy.pairs = {k: list(v) for k, v in self.pairs.items()}
            copy.windows = deque(self.windows)
            copy.pair_counts = dict(self.pair_counts)
            copy.closest = self.closest
            copy.hours = dict(self.hours)
            copy.messages = self.messages
        return copy


def kafka_reader(shared):
    """Background thread: reads the three topics forever and adds their rows."""
    consumer = KafkaConsumer(*TOPICS, bootstrap_servers=KAFKA_BROKERS,
                             auto_offset_reset="earliest", enable_auto_commit=False,
                             value_deserializer=lambda b: json.loads(b.decode("utf-8")))
    for msg in consumer:
        shared.add(msg.topic, msg.value)


@st.cache_resource
def rows():
    """The rows of the app, shared by every session, and the thread that fills them."""
    shared = Rows()
    threading.Thread(target=kafka_reader, args=(shared,), daemon=True).start()
    return shared


# ------------------------------------------------------------------------------- maps
def viridis(values, vmin, vmax):
    """The colours of the viridis scale for values between vmin and vmax."""
    t = np.clip((np.asarray(values, dtype=float) - vmin) / (vmax - vmin), 0, 1)
    t = t * (len(VIRIDIS) - 1)
    i = np.minimum(t.astype(int), len(VIRIDIS) - 2)
    f = (t - i)[:, None]
    return (VIRIDIS[i] * (1 - f) + VIRIDIS[i + 1] * f).astype(int).tolist()


def map_chart(layers, lat, lon, zoom, tooltip=None, height=340):
    """A map of pydeck layers over the base map."""
    deck = pdk.Deck(layers=layers, map_style=BASE_MAP,
                    initial_view_state=pdk.ViewState(latitude=lat, longitude=lon, zoom=zoom),
                    tooltip=tooltip)
    st.pydeck_chart(deck, height=height)


# ------------------------------------------------------------------------------- dashboards
def dashboard1(data):
    st.subheader("1. Flights leaving Brussels")
    climbing = pd.DataFrame(data.climbing, columns=["icao24", "callsign", "posts", "lon",
                                                    "lat", "geoaltitude", "vertrate"])
    c1, c2, c3 = st.columns(3)
    c1.metric("Positions", f"{len(climbing):,}")
    c2.metric("Aircraft", f"{climbing['icao24'].nunique():,}")
    c3.metric("Last position", climbing["posts"].max()[11:19] if len(climbing) else "-")
    left, right = st.columns(2)
    with left:
        heat = pdk.Layer("HeatmapLayer",
                         data=climbing.assign(weight=2000 - climbing["geoaltitude"]),
                         get_position=["lon", "lat"], get_weight="weight", radius_pixels=30)
        map_chart([heat], 50.86, 4.45, 9.6)
        st.caption("Noise heatmap: each position weighs 2,000 m minus its altitude")
    with right:
        climbing = climbing.assign(color=viridis(climbing["geoaltitude"], 0, 2000))
        points = pdk.Layer("ScatterplotLayer", data=climbing, get_position=["lon", "lat"],
                           get_fill_color="color", get_radius=60, radius_min_pixels=2,
                           pickable=True)
        map_chart([points], 50.86, 4.45, 9.6,
                  tooltip={"text": "{callsign} {geoaltitude} m at {posts}"})
        st.caption("Altitude, from 0 m (purple) to 2,000 m (yellow)")


def dashboard2(data):
    st.subheader("2. Close flights per window of ten minutes")
    counts = pd.DataFrame([(k, n, d) for k, (n, d) in data.pair_counts.items()],
                          columns=["window", "pairs", "smallest"]).sort_values("window")
    c1, c2, c3 = st.columns(3)
    c1.metric("Pairs within 1 km", f"{counts['pairs'].sum():,}")
    c2.metric("Windows with a pair", f"{len(counts):,}")
    if data.closest is not None:
        c3.metric("Closest so far", f"{data.closest['distance']:,.0f} m",
                  f"{data.closest['icao24_1']} / {data.closest['icao24_2']}",
                  delta_color="off")
    st.bar_chart(counts.assign(window=pd.to_datetime(counts["window"])), x="window", y="pairs",
                 height=190)
    recent = [row for start in list(data.windows)[-3:] for row in data.pairs.get(start, [])]
    if recent:
        st.dataframe(pd.DataFrame(recent).sort_values("distance").head(8),
                     hide_index=True, height=170)
    st.caption("The pairs of the last three windows, closest first")


def dashboard3(data):
    st.subheader("3. Air traffic per hour")
    hours = pd.DataFrame(list(data.hours.values()))
    if hours.empty:
        st.info("No hour has closed yet")
        return
    hours = hours.sort_values("window_start").assign(
        hour=lambda h: pd.to_datetime(h["window_start"]))
    last = hours.iloc[-1]
    c1, c2, c3 = st.columns(3)
    c1.metric(f"Positions {last['hour']:%H:%M}", f"{last['positions']:,}")
    c2.metric("Aircraft", f"{last['aircraft']:,}")
    c3.metric("Mean altitude", f"{last['altitude']:,.0f} m")
    st.bar_chart(hours, x="hour", y=["positions", "cruisingpositions"], stack=False,
                 height=190)
    st.line_chart(hours, x="hour", y=["aircraft", "cruisingaircraft"], height=170)


@st.fragment(run_every=REFRESH)
def dashboards():
    data = rows().snapshot()
    st.caption(f"{data.messages:,} rows read from Kafka")
    dashboard1(data)
    left, right = st.columns(2)
    with left:
        dashboard2(data)
    with right:
        dashboard3(data)


st.title("Air traffic over Europe as a stream")
st.caption("The continuous queries of MobilityFlink over the state vectors of March 1, 2026, "
           "replayed into Kafka")
dashboards()
