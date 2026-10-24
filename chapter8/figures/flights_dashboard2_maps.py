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

"""The figures of dashboard 2 of the flights use case of chapter 8, from the answers of MobilityDB.

    python flights_dashboard2_maps.py <answers> <out> <name1> <name2>
    then  render.sh <out> flightsDashboard2_map.json

<answers> holds d2_distance.csv (Time, Distance in km), d2_positions.csv (Time, Aircraft, Lat,
Lon, GeoAltitude) and d2_altitude.csv (Time, Aircraft, GeoAltitude), which flights_dashboard2.sql
writes; <name1> <name2> are the call signs of the aircraft 1 and 2. The figures draw the panels
of dashboard 2 of dashboards/app.py as the dashboard draws them: flightsDashboard2_distance.pdf
(the distance over time, in km) and flightsDashboard2_altitude.pdf (the geometric altitude of the
two aircraft over time, in meters, one line each with the legend below) as vector charts in Latin
Modern, the font of the book, and the QGIS job flightsDashboard2_map.json (the position reports
of the two aircraft as points over the Shortbread basemap, on the square around the two tracks
that the dashboard shows), which render.sh renders. Each aircraft has the color of
AIRCRAFT_COLORS of the dashboard.
"""
import sys

import matplotlib
matplotlib.use("pgf")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib import font_manager

from mapjob import TO3857, job, padded, points  # noqa: E402

ANSWERS, OUT = sys.argv[1], sys.argv[2]
TEXTWIDTH = 11.7 / 2.54
# The altitudes of panel (a) take 0.55 of the text width and the square map of panel (b) 0.43 of
# it, at the height of the chart
CHART_W = 0.55 * TEXTWIDTH
MAP_W = 0.43 * TEXTWIDTH
# AIRCRAFT_COLORS of dashboards/app.py, and the color of the line of st.line_chart
COLORS = {1: "#e6550d", 2: "#3182bd"}
LINE = "#0068c9"
for f in ("lmroman10-regular.otf", "lmroman10-bold.otf"):
    font_manager.fontManager.addfont(f"/usr/share/texmf/fonts/opentype/public/lm/{f}")
plt.rcParams.update({"pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
                     "font.family": "serif", "font.size": 8,
                     "axes.linewidth": 0.5, "xtick.major.width": 0.5, "ytick.major.width": 0.5,
                     "axes.spines.top": False, "axes.spines.right": False,
                     "axes.grid": True, "axes.grid.axis": "y", "grid.linewidth": 0.3,
                     "grid.color": "#d9d9d9"})
HOURS = mdates.DateFormatter("%H:%M")


def times(df):
    df = df.rename(columns=str.title).rename(columns={"Geoaltitude": "GeoAltitude"})
    return df.assign(Time=pd.to_datetime(df["Time"], utc=True, format="ISO8601").dt.tz_convert(None))


def distance():
    d = times(pd.read_csv(f"{ANSWERS}/d2_distance.csv"))
    fig, ax = plt.subplots(figsize=(TEXTWIDTH, 1.9))
    ax.plot(d.Time, d.Distance, color=LINE, linewidth=0.8)
    ax.set_ylim(bottom=0)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:,.0f}")
    ax.set_ylabel("Distance (km)")
    ax.set_xlabel("Time (UTC), March 1, 2026")
    ax.xaxis.set_major_formatter(HOURS)
    fig.tight_layout(pad=0.2)
    fig.savefig(f"{OUT}/flightsDashboard2_distance.pdf")
    return len(d)


def altitude(names):
    a = times(pd.read_csv(f"{ANSWERS}/d2_altitude.csv"))
    fig, ax = plt.subplots(figsize=(CHART_W, MAP_W))
    for k in (1, 2):
        r = a[a.Aircraft == k].dropna(subset=["GeoAltitude"])
        ax.plot(r.Time, r.GeoAltitude, color=COLORS[k], linewidth=0.8, label=names[k])
    ax.set_ylim(bottom=0)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:,.0f}")
    ax.set_ylabel("Altitude (m)")
    ax.set_xlabel("Time (UTC)")
    ax.xaxis.set_major_locator(mdates.HourLocator())
    ax.xaxis.set_major_formatter(HOURS)
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.22), ncol=2, frameon=False,
              handlelength=1.2)
    fig.tight_layout(pad=0.2)
    fig.savefig(f"{OUT}/flightsDashboard2_altitude.pdf")
    return {k: int((a.Aircraft == k).sum()) for k in (1, 2)}


def mapjob():
    p = pd.read_csv(f"{ANSWERS}/d2_positions.csv").rename(columns=str.title)
    x, y = TO3857.transform(p.Lon.values, p.Lat.values)
    x0, x1, y0, y1 = padded(x, y, 60_000)
    # The square around the two tracks with a margin of 60 km, as the dashboard draws it
    cx, cy, half = (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) / 2
    extent = (cx - half, cx + half, cy - half, cy + half)
    layers = []
    for k in (1, 2):
        r = p[p.Aircraft == k]
        points(f"{OUT}/flightsDashboard2_reports{k}.geojson", r.Lon, r.Lat)
        rgb = ",".join(str(int(COLORS[k][i:i + 2], 16)) for i in (1, 3, 5))
        layers.append({"path": f"flightsDashboard2_reports{k}.geojson", "kind": "marker",
                       "style": {"name": "circle", "color": rgb + ",255", "outline_style": "no",
                                 "size": "0.6"}})
    job(OUT, "flightsDashboard2_map", extent, MAP_W, layers, streets=None, border="#9a9a9a")
    return {k: int((p.Aircraft == k).sum()) for k in (1, 2)}


if __name__ == "__main__":
    names = {1: sys.argv[3], 2: sys.argv[4]}
    print("distance rows", distance())
    print("altitude rows", altitude(names))
    print("position rows", mapjob())
