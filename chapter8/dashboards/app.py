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

"""The three dashboards of the air traffic use case of chapter 8, in Streamlit over MobilitySpark.

The app is a client of Spark Connect: every query runs in the Spark Connect server, where the
extension of MobilitySpark named in spark.sql.extensions registers the typed SQL surface on the
session of each client. The tables are those that the notebook "8.3 Create tables from
scratch-flights-MobilitySpark" writes into the warehouse; the app declares them on its session
from their Delta folders, and builds once the tables of dashboard 2 with dashboards_tables.sql.
The queries of the dashboards are the files dashboard1.sql, dashboard2.sql and dashboard3.sql,
one panel per statement. A query returns plain values (numbers, timestamps, longitudes and
latitudes), which the client of Spark Connect reads into pandas.

The page shows the three dashboards one below the other, as the page of the stream dashboards of
chapter 9 (chapter9/Flink_Examples/flights_stream/app.py) does. The maps are pydeck layers, as
the maps of the notebook "8.2 Queries and Visualization" are, each on the extent of its figure in
the chapter and with the scale of its colors below it, over the OSM Shortbread vector tiles
in the colors of the maps of the book: the style static/shortbread.json, which the app serves
itself, the style of the app of chapter 9.

    SPARK_REMOTE=sc://localhost:15002 WAREHOUSE=hdfs://namenode:9000/spark-warehouse \
        streamlit run app.py --server.enableStaticServing true --theme.base light \
        --client.toolbarMode viewer
"""
import math
import os
import re
import time

import altair as alt
import numpy as np
import pandas as pd
import pydeck as pdk
import streamlit as st

HERE = os.path.dirname(os.path.abspath(__file__))
SPARK_REMOTE = os.environ.get("SPARK_REMOTE", "sc://localhost:15002")
WAREHOUSE = os.environ.get("WAREHOUSE", "hdfs://namenode:9000/spark-warehouse")
NOTEBOOK_TABLES = ["flightsinput", "flightspositions", "flightsday", "flights"]
DASHBOARD_TABLES = ["flightseu", "flightseu3d", "airborne3d", "closepair"]
VIRIDIS = np.array([[68, 1, 84], [59, 82, 139], [33, 145, 140], [94, 201, 98], [253, 231, 37]])
# The colors of the heat maps: those that deck.gl gives a HeatmapLayer by default
HEAT = [[255, 255, 178], [254, 217, 118], [254, 178, 76], [253, 141, 60], [240, 59, 32],
        [189, 0, 38]]
AIRCRAFT_COLORS = {1: [230, 85, 13], 2: [49, 130, 189]}
# The base map: a MapLibre style over the OSM Shortbread vector tiles, served by the app
BASE_MAP = f"http://localhost:{st.get_option('server.port')}/app/static/shortbread.json"
MAX_POINTS = 100_000  # the positions a map of dashboard 3 draws, at most
R = 6378137.0  # the radius of the sphere of EPSG:3857, in meters
# The extents of the maps, in EPSG:3857, those of their figures in chapter8.tex: the envelope of
# Brussels to which the query of dashboard 1 restricts the positions with a margin, and Europe
# where the positions of dashboard 3 lie
BRUSSELS = (4.20, 4.65, 50.72, 50.98)
EUROPE = (-20.0, 40.0, 30.0, 66.0)
MAP_WIDTH = 500  # pixels of a map of dashboards 1 and 3

st.set_page_config(page_title="Air traffic over Europe", layout="wide")


# ------------------------------------------------------------------------------- Spark
@st.cache_resource
def spark():
    """The session of the app in the Spark Connect server, with the tables of the use case."""
    from pyspark.errors import AnalysisException
    from pyspark.sql import SparkSession
    session = SparkSession.builder.remote(SPARK_REMOTE).getOrCreate()
    session.conf.set("spark.sql.session.timeZone", "UTC")
    for table in NOTEBOOK_TABLES:
        session.sql(f"CREATE TABLE IF NOT EXISTS {table} USING DELTA "
                    f"LOCATION '{WAREHOUSE}/{table}'")
    # The tables of dashboard 2 from their folders as well, once built: a folder that does not
    # hold a Delta table yet fails to read, and leaves the table to the button of the dashboard
    # (CREATE TABLE on such a folder would create an empty table there)
    for table in DASHBOARD_TABLES:
        try:
            session.read.format("delta").load(f"{WAREHOUSE}/{table}").schema
        except AnalysisException:
            continue
        session.sql(f"CREATE TABLE IF NOT EXISTS {table} USING DELTA "
                    f"LOCATION '{WAREHOUSE}/{table}'")
    return session


def statements(name):
    """The statements of a file of queries, without its comments."""
    with open(os.path.join(HERE, name)) as f:
        text = re.sub(r"/\*.*?\*/", "", f.read(), flags=re.S)
    lines = [ln for ln in text.splitlines() if not ln.lstrip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


@st.cache_data(show_spinner=False)
def panel(name, index):
    """The rows of one panel, the statement at a given position of a file, with its time."""
    start = time.time()
    rows = spark().sql(statements(name)[index]).toPandas()
    return rows, time.time() - start


def dashboard_tables_exist():
    names = {r.tableName for r in spark().sql("SHOW TABLES").collect()}
    return all(t in names for t in DASHBOARD_TABLES)


# ------------------------------------------------------------------------------- maps
def viridis(values, vmin, vmax):
    """The colours of the viridis scale for values between vmin and vmax."""
    t = np.clip((np.asarray(values, dtype=float) - vmin) / (vmax - vmin), 0, 1)
    t = t * (len(VIRIDIS) - 1)
    i = np.minimum(t.astype(int), len(VIRIDIS) - 2)
    f = (t - i)[:, None]
    return (VIRIDIS[i] * (1 - f) + VIRIDIS[i + 1] * f).astype(int).tolist()


def map_chart(layers, lat, lon, zoom, tooltip=None, height=340, width="stretch"):
    """A map of pydeck layers over the base map, of the height of #map_chart in the app of
    chapter 9, drawn as the maps of the notebook 8.2 are."""
    deck = pdk.Deck(layers=layers, map_style=BASE_MAP,
                    initial_view_state=pdk.ViewState(latitude=lat, longitude=lon, zoom=zoom),
                    tooltip=tooltip)
    st.pydeck_chart(deck, height=height, width=width)


def mercator(lon, lat):
    """The coordinates in EPSG:3857 of a longitude and a latitude."""
    return R * math.radians(lon), R * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))


def extent_map(layers, extent, width, tooltip=None):
    """A map by #map_chart, width pixels wide, of exactly the extent x0, x1, y0, y1 of EPSG:3857,
    that of its figure in the book (#extent3857 of figures/mapjob.py): the zoom at which the
    extent fills the width, on the tiles of 512 pixels of deck.gl, and the height of the extent
    at this zoom."""
    x0, x1, y0, y1 = extent
    zoom = math.log2(width * 2 * math.pi * R / (512 * (x1 - x0)))
    lon = math.degrees((x0 + x1) / 2 / R)
    lat = math.degrees(2 * math.atan(math.exp((y0 + y1) / 2 / R)) - math.pi / 2)
    map_chart(layers, lat, lon, zoom, tooltip, height=round(width * (y1 - y0) / (x1 - x0)),
              width=width)


def lonlat_extent(lon0, lon1, lat0, lat1):
    """The extent in EPSG:3857 of a range of longitudes and of latitudes."""
    (x0, y0), (x1, y1) = mercator(lon0, lat0), mercator(lon1, lat1)
    return x0, x1, y0, y1


def color_scale(title, colors, ticks, width=MAP_WIDTH):
    """The scale of the colors of a map, set under it, width pixels wide, as #overlay of
    figures/flights_maps.py sets the scale of the figures of the book: its title, a bar of the
    colors and the labels of ticks, a list of (fraction of the bar, label)."""
    stops = ", ".join(f"rgb({r},{g},{b}) {100 * i / (len(colors) - 1):.0f}%"
                      for i, (r, g, b) in enumerate(colors))
    labels = "".join(
        f'<span style="position:absolute; left:{100 * f:.2f}%; '
        f'transform:translateX(-{100 * f:.0f}%)">{label}</span>' for f, label in ticks)
    st.html(f'<div style="width:{width}px; font-size:0.875rem; color:rgba(49,51,63,0.6)">'
            f'{title}'
            f'<div style="height:10px; margin-top:4px; border:1px solid rgba(49,51,63,0.3); '
            f'background:linear-gradient(to right, {stops})"></div>'
            f'<div style="position:relative; height:1.4em">{labels}</div></div>')


def altitude_scale(title, top, step):
    """The viridis scale of the altitudes from 0 to top meters, with a tick every step meters,
    by #color_scale."""
    color_scale(title, VIRIDIS.tolist(), [(m / top, f"{m:,}") for m in range(0, top + 1, step)])


# ------------------------------------------------------------------------------- dashboards
def dashboard1():
    st.subheader("1. Flights leaving Brussels")
    st.caption("The positions below 2,000 m of the flights over Brussels while they climb")
    with st.spinner("MobilitySpark answers the panel"):
        rows, seconds = panel("dashboard1.sql", 0)
    c1, c2, c3 = st.columns(3)
    c1.metric("Positions", f"{len(rows):,}")
    c2.metric("Aircraft", f"{rows['ICAO24'].nunique():,}")
    c3.metric("Spark query", f"{seconds:.1f} s")
    left, right = st.columns(2)
    with left:
        heat = pdk.Layer("HeatmapLayer", data=rows.assign(Weight=2000 - rows["GeoAltitude"]),
                         get_position=["Lon", "Lat"], get_weight="Weight", radius_pixels=30,
                         color_range=HEAT)
        extent_map([heat], lonlat_extent(*BRUSSELS), MAP_WIDTH)
        color_scale("Noise: each position weighs 2,000 m minus its geometric altitude", HEAT,
                    [(0, "low"), (1, "high")])
    with right:
        rows = rows.assign(color=viridis(rows["GeoAltitude"], 0, 2000),
                           Time=rows["T"].astype(str))
        points = pdk.Layer("ScatterplotLayer", data=rows, get_position=["Lon", "Lat"],
                           get_fill_color="color", get_radius=60, radius_min_pixels=2,
                           pickable=True)
        extent_map([points], lonlat_extent(*BRUSSELS), MAP_WIDTH,
                   tooltip={"text": "{CallSign} {GeoAltitude} m at {Time}"})
        altitude_scale("Geometric altitude (m)", 2000, 500)


def dashboard2():
    st.subheader("2. The two flights that come the closest to each other")
    if not dashboard_tables_exist():
        st.info("The tables of this dashboard are built once from the flights tables; "
                "the closest pair takes the longest.")
        if st.button("Build the tables of dashboard 2"):
            with st.spinner("MobilitySpark builds FlightsEU, FlightsEU3D, Airborne3D and "
                            "ClosePair"):
                for statement in statements("dashboards_tables.sql"):
                    spark().sql(statement).collect()
            st.rerun()
        return
    pair = spark().sql("SELECT * FROM ClosePair").toPandas().iloc[0]
    st.caption(f"{pair['CallSign_1']} ({pair['ICAO24_1']}) and {pair['CallSign_2']} "
               f"({pair['ICAO24_2']}) come within {pair['Distance']:,.2f} m of each other "
               "in three dimensions, over Europe, while both fly")
    with st.spinner("MobilitySpark answers the panels"):
        distance, _ = panel("dashboard2.sql", 0)
        positions, _ = panel("dashboard2.sql", 1)
        altitude1, _ = panel("dashboard2.sql", 2)
        altitude2, _ = panel("dashboard2.sql", 3)
    c1, c2, c3 = st.columns(3)
    with c1:
        st.caption("Distance between the two planes (km)")
        st.line_chart(distance, x="Time", y="Distance", height=300)
    with c2:
        st.caption("Geometric altitude (m)")
        altitude = pd.concat([altitude1.assign(Flight=pair["CallSign_1"]),
                              altitude2.assign(Flight=pair["CallSign_2"])])
        colors = alt.Scale(domain=[pair["CallSign_1"], pair["CallSign_2"]],
                           range=["#{:02x}{:02x}{:02x}".format(*AIRCRAFT_COLORS[i])
                                  for i in (1, 2)])
        chart = alt.Chart(altitude).mark_line().encode(
            x=alt.X("EtTs:T", title="time"), y=alt.Y("GeoAltitude:Q", title="altitude"),
            color=alt.Color("Flight:N", scale=colors,
                            legend=alt.Legend(orient="bottom", title=None)))
        st.altair_chart(chart, height=300)
    with c3:
        st.caption("Position of the close flights")
        names = {1: pair["CallSign_1"], 2: pair["CallSign_2"]}
        positions = positions.assign(color=positions["Aircraft"].map(AIRCRAFT_COLORS),
                                     Flight=positions["Aircraft"].map(names),
                                     T=positions["PosTs"].astype(str))
        points = pdk.Layer("ScatterplotLayer", data=positions, get_position=["Lon", "Lat"],
                           get_fill_color="color", get_radius=400, radius_min_pixels=2,
                           pickable=True)
        # The square around the two tracks with a margin of 60 km, as #mapjob of
        # figures/flights_dashboard2_maps.py draws it
        x, y = zip(*map(mercator, positions["Lon"], positions["Lat"]))
        cx, cy = (min(x) + max(x)) / 2, (min(y) + max(y)) / 2
        half = max(max(x) - min(x), max(y) - min(y)) / 2 + 60_000
        extent_map([points], (cx - half, cx + half, cy - half, cy + half), 300,
                   tooltip={"text": "{Flight} at {T}"})


def dashboard3():
    st.subheader("3. Air traffic between 8 and 9 o'clock")
    st.caption("The figures count the flights of the data all over the world; the maps show "
               "Europe")
    for column, index, caption in zip(st.columns(2), [0, 1], [
            "GPS location over time: all the positions",
            "Cruising flights: the positions between 3,000 and 8,000 m"]):
        with column:
            st.caption(caption)
            with st.spinner("MobilitySpark answers the panel"):
                rows, seconds = panel("dashboard3.sql", index)
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("Positions", f"{len(rows):,}")
            c2.metric("Aircraft", f"{rows['ICAO24'].nunique():,}")
            c3.metric("Mean altitude", f"{rows['Altitude'].mean():,.0f} m")
            c4.metric("Spark query", f"{seconds:.1f} s")
            shown = rows.dropna(subset=["Lon", "Lat", "Altitude"])
            if len(shown) > MAX_POINTS:
                shown = shown.sample(n=MAX_POINTS, random_state=0)
            shown = shown.assign(color=viridis(shown["Altitude"], 0, 12000))
            points = pdk.Layer("ScatterplotLayer", data=shown, get_position=["Lon", "Lat"],
                               get_fill_color="color", get_radius=1500, radius_min_pixels=1)
            extent_map([points], lonlat_extent(*EUROPE), MAP_WIDTH)
            altitude_scale(f"Altitude (m) of {len(shown):,} positions drawn at random",
                           12000, 3000)


st.title("Air traffic over Europe")
st.caption("The queries of MobilitySpark over the state vectors of March 1, 2026")
dashboard1()
dashboard2()
dashboard3()
