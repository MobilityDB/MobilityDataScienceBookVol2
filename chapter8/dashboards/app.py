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
the maps of the notebook "8.2 Queries and Visualization" are, over the OSM Shortbread vector tiles
in the colors of the maps of the book: the style static/shortbread.json, which the app serves
itself, the style of the app of chapter 9.

    SPARK_REMOTE=sc://localhost:15002 WAREHOUSE=hdfs://namenode:9000/spark-warehouse \
        streamlit run app.py --server.enableStaticServing true --theme.base light \
        --client.toolbarMode viewer
"""
import math
import os
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
AIRCRAFT_COLORS = {1: [230, 85, 13], 2: [49, 130, 189]}
# The base map: a MapLibre style over the OSM Shortbread vector tiles, served by the app
BASE_MAP = f"http://localhost:{st.get_option('server.port')}/app/static/shortbread.json"
MAX_POINTS = 100_000  # the positions a map of dashboard 3 draws, at most

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
        lines = [ln for ln in f.read().splitlines() if not ln.lstrip().startswith("--")]
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


def map_chart(layers, lat, lon, zoom, tooltip=None, height=340):
    """A map of pydeck layers over the base map, of the height of #map_chart in the app of
    chapter 9, drawn as the maps of the notebook 8.2 are."""
    deck = pdk.Deck(layers=layers, map_style=BASE_MAP,
                    initial_view_state=pdk.ViewState(latitude=lat, longitude=lon, zoom=zoom),
                    tooltip=tooltip)
    st.pydeck_chart(deck, height=height)


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
                         get_position=["Lon", "Lat"], get_weight="Weight", radius_pixels=30)
        map_chart([heat], 50.86, 4.45, 9.6)
        st.caption("Noise heatmap: each position weighs 2,000 m minus its geometric altitude")
    with right:
        rows = rows.assign(color=viridis(rows["GeoAltitude"], 0, 2000),
                           Time=rows["T"].astype(str))
        points = pdk.Layer("ScatterplotLayer", data=rows, get_position=["Lon", "Lat"],
                           get_fill_color="color", get_radius=60, radius_min_pixels=2,
                           pickable=True)
        map_chart([points], 50.86, 4.45, 9.6,
                  tooltip={"text": "{CallSign} {GeoAltitude} m at {Time}"})
        st.caption("Geometric altitude, from 0 m (purple) to 2,000 m (yellow)")


def dashboard2():
    st.subheader("2. The two flights that come the closest to each other")
    if not dashboard_tables_exist():
        st.info("The tables of this dashboard are built once from the flights tables; "
                "the closest pair takes the longest.")
        if st.button("Build the tables of dashboard 2"):
            with st.spinner("MobilitySpark builds flightseu, flightseu3d, airborne3d and "
                            "closepair"):
                for statement in statements("dashboards_tables.sql"):
                    spark().sql(statement).collect()
            st.rerun()
        return
    pair = spark().sql("SELECT * FROM closepair").toPandas().iloc[0]
    st.caption(f"{pair['callsign_1']} ({pair['icao24_1']}) and {pair['callsign_2']} "
               f"({pair['icao24_2']}) come within {pair['distance']:,.2f} m of each other "
               "in three dimensions, over Europe, while both fly")
    with st.spinner("MobilitySpark answers the panels"):
        distance, _ = panel("dashboard2.sql", 0)
        positions, _ = panel("dashboard2.sql", 1)
        altitude1, _ = panel("dashboard2.sql", 2)
        altitude2, _ = panel("dashboard2.sql", 3)
    c1, c2, c3 = st.columns(3)
    with c1:
        st.caption("Distance between the two planes (km)")
        st.line_chart(distance, x="time", y="distance", height=300)
    with c2:
        st.caption("Geometric altitude (m)")
        altitude = pd.concat([altitude1.assign(Flight=pair["callsign_1"]),
                              altitude2.assign(Flight=pair["callsign_2"])])
        colors = alt.Scale(domain=[pair["callsign_1"], pair["callsign_2"]],
                           range=["#{:02x}{:02x}{:02x}".format(*AIRCRAFT_COLORS[i])
                                  for i in (1, 2)])
        chart = alt.Chart(altitude).mark_line().encode(
            x=alt.X("etts:T", title="time"), y=alt.Y("geoaltitude:Q", title="altitude"),
            color=alt.Color("Flight:N", scale=colors,
                            legend=alt.Legend(orient="bottom", title=None)))
        st.altair_chart(chart, height=300)
    with c3:
        st.caption("Position of the close flights")
        names = {1: pair["callsign_1"], 2: pair["callsign_2"]}
        positions = positions.assign(color=positions["aircraft"].map(AIRCRAFT_COLORS),
                                     Flight=positions["aircraft"].map(names),
                                     T=positions["posts"].astype(str))
        points = pdk.Layer("ScatterplotLayer", data=positions, get_position=["lon", "lat"],
                           get_fill_color="color", get_radius=400, radius_min_pixels=2,
                           pickable=True)
        width = max(positions["lon"].max() - positions["lon"].min(), 0.1)
        zoom = max(1.0, min(8.0, math.log2(180 / width)))
        map_chart([points], positions["lat"].mean(), positions["lon"].mean(), zoom,
                  tooltip={"text": "{Flight} at {T}"}, height=300)


def dashboard3():
    st.subheader("3. Air traffic between 8 and 9 o'clock")
    st.caption("The figures count the flights of the data all over the world; the maps are "
               "centred on Europe")
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
            map_chart([points], 50.0, 10.0, 2.9)
            st.caption(f"Altitude, from 0 m (purple) to 12,000 m (yellow), of {len(shown):,} "
                       "positions drawn at random")


st.title("Air traffic over Europe")
st.caption("The queries of MobilitySpark over the state vectors of March 1, 2026")
dashboard1()
dashboard2()
dashboard3()
