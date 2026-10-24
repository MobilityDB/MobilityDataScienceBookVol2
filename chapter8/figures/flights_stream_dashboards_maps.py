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

"""Write the figures of the dashboards of the air traffic stream of the chapter Mobility Streams,
the panels of chapter9/Flink_Examples/flights_stream/app.py drawn as the app draws them, as
flights_maps.py and flights_dashboard2_maps.py write those of the dashboards of the chapter
Large-Scale Mobility Databases, whose helpers they reuse.

    python flights_stream_dashboards_maps.py <session> <out>   then  render.sh <out>

<session> holds the dumps of the output topics of the dashboards job flights_dashboards.py over
the whole day, which measure/dashboards_session.sh of chapter 9 writes: d1.json (the rows of
climbing-brussels), d2.json (those of close-pairs) and summary.json, whose d3 holds those of
traffic-per-hour. Dashboard 1 is the two maps of flightsDashboard1 of flights_maps.py on the same
extent, the noise heat map and the positions colored by their altitude, each set by
<panel>_scaled.tex with the scale of its colors under it. Dashboard 2 is the bar chart of the
pairs per window of ten minutes, and dashboard 3 the bar chart of the positions and of the
cruising positions per hour, the bars of the two series one in front of the other as
st.bar_chart draws them with stack=False, and the line chart of the aircraft and of the cruising
aircraft per hour, vector charts in Latin Modern in the colors of the charts of Streamlit.
"""
import json
import sys

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd

from flights_dashboard2_maps import HOURS, LINE, TEXTWIDTH
from flights_maps import (HEAT, PANEL, VIRIDIS, altitude_ticks, colors, heat_image, project,
                          scaled)
from mapjob import extent3857, job, points

# The second color of the charts of Streamlit, after LINE; the series are in the order of their
# names, as Streamlit orders them
LIGHT = "#83c9ff"
MINUTE = 1 / 1440  # a minute in the days of the dates of matplotlib


def dashboard1(session, out):
    rows = pd.DataFrame(json.load(open(f"{session}/d1.json")))
    rows = project(rows.rename(columns={"lon": "Lon", "lat": "Lat", "geoaltitude": "GeoAltitude"}))
    # The envelope of Brussels to which the query restricts the positions, as flights_maps.py
    extent = extent3857(4.20, 4.65, 50.72, 50.98)
    heat_image(rows, extent, f"{out}/flightsStreamDashboard1_heat.png")
    job(out, "flightsStreamDashboard1_left", extent, PANEL, [
        {"type": "raster", "path": "flightsStreamDashboard1_heat.png", "image": True}])
    points(f"{out}/flightsStreamDashboard1_positions.geojson", rows.Lon, rows.Lat,
           colors(rows["GeoAltitude"], 2000))
    job(out, "flightsStreamDashboard1_right", extent, PANEL, [
        {"path": "flightsStreamDashboard1_positions.geojson", "kind": "marker",
         "color_field": "color",
         "style": {"name": "circle", "color": "0,0,0,255", "outline_style": "no", "size": "0.35"}}])
    scaled(out, "flightsStreamDashboard1_left", HEAT, [(0, "low"), (1, "high")], "Noise",
           figs="figs/chap9")
    scaled(out, "flightsStreamDashboard1_right", VIRIDIS, altitude_ticks(2000, 500),
           "Altitude (m)", figs="figs/chap9")
    return len(rows), rows["icao24"].nunique()


def dashboard2(session, out):
    pairs = pd.DataFrame(json.load(open(f"{session}/d2.json")))
    counts = pairs.groupby("window_start").size().rename("pairs").reset_index()
    counts["window"] = pd.to_datetime(counts["window_start"])
    fig, ax = plt.subplots(figsize=(TEXTWIDTH, 1.9))
    ax.bar(mdates.date2num(counts["window"]) + 5 * MINUTE, counts["pairs"], width=8 * MINUTE,
           color=LINE)
    ax.xaxis_date()
    ax.set_ylabel("Pairs")
    ax.set_xlabel("Window of ten minutes (UTC), March 1, 2026")
    ax.xaxis.set_major_locator(mdates.HourLocator(interval=2))
    ax.xaxis.set_major_formatter(HOURS)
    fig.tight_layout(pad=0.2)
    fig.savefig(f"{out}/flightsStreamDashboard2.pdf")
    return len(pairs), len(counts)


def dashboard3(session, out):
    hours = pd.DataFrame(json.load(open(f"{session}/summary.json"))["d3"])
    hours["hour"] = pd.to_datetime(hours["window_start"])
    middle = mdates.date2num(hours["hour"]) + 30 * MINUTE
    for stem, series, draw in (
            ("positions", (("cruisingpositions", "cruising positions"), ("positions", "positions")),
             "bar"),
            ("aircraft", (("aircraft", "aircraft"), ("cruisingaircraft", "cruising aircraft")),
             "line")):
        fig, ax = plt.subplots(figsize=(TEXTWIDTH, 1.7))
        # The bars of the larger series behind those of the smaller one, which stays visible
        order = sorted(zip(series, (LINE, LIGHT)), key=lambda s: -hours[s[0][0]].sum())
        for (column, label), color in order:
            if draw == "bar":
                ax.bar(middle, hours[column], width=48 * MINUTE, color=color,
                       label=label)
            else:
                ax.plot(middle, hours[column], color=color, linewidth=0.8, label=label)
        # The legend in the order of the names of the series, whatever the order of drawing
        named = dict(zip(*reversed(ax.get_legend_handles_labels())))
        ax.legend([named[label] for _, label in series], [label for _, label in series],
                  loc="upper center",
                  bbox_to_anchor=(0.5, -0.32), ncol=2, frameon=False, handlelength=1.2)
        ax.xaxis_date()
        ax.set_ylim(bottom=0)
        ax.yaxis.set_major_formatter(lambda v, _: f"{v:,.0f}")
        ax.set_ylabel(stem.capitalize())
        ax.set_xlabel("Hour (UTC)")
        # The 25 hours, labeled every three hours from midnight
        ax.set_xlim(middle.min() - 30 * MINUTE, middle.max() + 30 * MINUTE)
        ax.xaxis.set_major_locator(mdates.HourLocator(byhour=range(0, 24, 3)))
        ax.xaxis.set_major_formatter(HOURS)
        fig.tight_layout(pad=0.2)
        fig.savefig(f"{out}/flightsStreamDashboard3_{stem}.pdf")
    return len(hours)


if __name__ == "__main__":
    SESSION, OUT = sys.argv[1], sys.argv[2]
    print("dashboard 1: positions, aircraft", dashboard1(SESSION, OUT))
    print("dashboard 2: pairs, windows", dashboard2(SESSION, OUT))
    print("dashboard 3: hours", dashboard3(SESSION, OUT))
