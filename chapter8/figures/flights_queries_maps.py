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

"""Write the maps of the queries of the analysis of the flights over Europe of the chapter
Large-Scale Mobility Databases, as flights_maps.py writes those of the dashboards.

    python flights_queries_maps.py <answers> <out>   then  render.sh <out>

<answers> holds the answers of MobilitySpark as CSV, the folder flights_queries that the
notebook 8.4 Queries-flights-MobilitySpark writes beside itself: q1_rows.csv (the trajectory of
each flight over Europe between 8 and 9 o'clock, in WKT of WGS84), q2_rows.csv (the route and
the destination of each flight leaving Brussels), q3_rows.csv (the flights over each country,
the distance they fly there and the boundary of the country from Natural Earth), q4_series.csv
(the number of aircraft in the air over Europe at each instant of the day, a temporal integer in
its text form) and q5_rows.csv (the part of each flight within 15 km of a holding fix of London
Heathrow and its trajectory). Each map of Europe is one QGIS job (#job of mapjob.py) of the
extent EUROPE and the width MAPWIDTH, shared with the maps of flights_stream_maps.py, rendered by
qgis_map.py over the Shortbread basemap of the book: the 5,086 trajectories of query 1 and the routes of query 2, dense layers,
as one image of 300 dpi each; the destinations of query 2 and the countries of query 3 as
vectors. The countries are colored by their distance on a logarithmic viridis scale, whose
LaTeX scale flightsQuery3_scale.tex is written beside the job as flights_maps.py writes
#vertical_scale. The count of query 4 is a vector chart in Latin Modern, the font of the book,
drawn as the charts of dashboard 2; the holding of query 5 is a QGIS job of the trajectories near
the four fixes, colored by fix, with the circle of 15 km around each fix on the WGS 84 spheroid.
"""
import json
import math
import re
import sys

import matplotlib
matplotlib.use("pgf")
import matplotlib.dates as mdates  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib import colormaps, font_manager  # noqa: E402
from pyproj import Geod  # noqa: E402
from shapely.geometry import Point, Polygon  # noqa: E402
from shapely import wkt  # noqa: E402
from shapely.geometry import mapping  # noqa: E402

from mapjob import extent3857, job, rgba  # noqa: E402

# The maps of Europe of chapters 8 and 9 share one extent, the envelope of Europe of the queries in
# longitude and, in latitude, from the Canary Islands to just above the northern tip of Finland
# (70.09 N), and one size, a height of 0.4 of the text height of the book (191 mm), its width that
# of the extent
TEXTHEIGHT = 19.1 / 2.54         # inches
# The line colors of the flights, as QGIS RGBA, shared with flights_stream_maps.py: all the flights
# in a dark blue, the departures from Brussels in red and the arrivals at Brussels in a dark green
FLIGHTS_COLOR = "8,69,148,130"
DEPARTURES_COLOR = "214,39,40,150"
ARRIVALS_COLOR = "0,109,44,170"
EUROPE = (-35.6, 44.8, 27.0, 70.2)
_X0, _X1, _Y0, _Y1 = extent3857(*EUROPE)
MAPWIDTH = 0.4 * TEXTHEIGHT * (_X1 - _X0) / (_Y1 - _Y0)

TEXTWIDTH = 11.7 / 2.54          # inches
VIRIDIS = colormaps["viridis"]
FIXES = {"Bovingdon": (-0.5500, 51.7260), "Lambourne": (0.1520, 51.6460),
         "Ockham": (-0.4470, 51.3050), "Biggin Hill": (0.0350, 51.3310)}
FIX_COLORS = {"Bovingdon": "214,39,40", "Lambourne": "31,119,180", "Ockham": "44,160,44",
              "Biggin Hill": "148,103,189"}
for font in ("lmroman10-regular.otf", "lmroman10-bold.otf"):
    font_manager.fontManager.addfont(f"/usr/share/texmf/fonts/opentype/public/lm/{font}")
plt.rcParams.update({"pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
                     "font.family": "serif", "font.size": 8,
                     "axes.linewidth": 0.5, "xtick.major.width": 0.5, "ytick.major.width": 0.5,
                     "axes.spines.top": False, "axes.spines.right": False})


def features(path, rows):
    """A GeoJSON file of the (geometry, properties) pairs of rows."""
    json.dump({"type": "FeatureCollection", "features": [
        {"type": "Feature", "properties": props, "geometry": mapping(geom)}
        for geom, props in rows]}, open(path, "w"))


def inside(lon, lat, ext):
    return ext[0] <= lon <= ext[1] and ext[2] <= lat <= ext[3]


def query1():
    rows = pd.read_csv(f"{ANSWERS}/q1_rows.csv")
    features(f"{OUT}/flightsQuery1_trips.geojson", [(wkt.loads(w), {}) for w in rows.WKT])
    job(OUT, "flightsQuery1", extent3857(*EUROPE), MAPWIDTH, [
        {"path": "flightsQuery1_trips.geojson", "kind": "line", "image": True,
         "style": {"line_color": FLIGHTS_COLOR, "line_width": "0.12"}}],
        streets=None, border="#9a9a9a")
    return len(rows)


def query2():
    rows = pd.read_csv(f"{ANSWERS}/q2_rows.csv")
    dest = [wkt.loads(w) for w in rows.Destination]
    features(f"{OUT}/flightsQuery2_routes.geojson", [(wkt.loads(w), {}) for w in rows.WKT])
    features(f"{OUT}/flightsQuery2_destinations.geojson", [(p, {}) for p in dest])
    job(OUT, "flightsQuery2", extent3857(*EUROPE), MAPWIDTH, [
        {"path": "flightsQuery2_routes.geojson", "kind": "line", "image": True,
         "style": {"line_color": DEPARTURES_COLOR, "line_width": "0.15"}},
        {"path": "flightsQuery2_destinations.geojson", "kind": "marker",
         "style": {"name": "circle", "color": "0,0,0,255", "outline_style": "no", "size": "0.6"}}],
        streets=None, border="#9a9a9a")
    outside = sum(not inside(p.x, p.y, EUROPE) for p in dest)
    return len(rows), outside


def query3():
    rows = pd.read_csv(f"{ANSWERS}/q3_rows.csv")
    vmax = 10 ** math.ceil(math.log10(rows.Km.max()))
    vmin = 10 ** math.floor(math.log10(rows.Km.min()))
    shapes = []
    for _, c in rows.iterrows():
        f = (math.log10(c.Km) - math.log10(vmin)) / (math.log10(vmax) - math.log10(vmin))
        color = rgba([round(255 * v) for v in VIRIDIS(f)[:3]] + [210])
        shapes.append((wkt.loads(c.WKT), {"color": color}))
    features(f"{OUT}/flightsQuery3_countries.geojson", shapes)
    job(OUT, "flightsQuery3", extent3857(*EUROPE), MAPWIDTH, [
        {"path": "flightsQuery3_countries.geojson", "kind": "fill", "color_field": "color",
         "style": {"color": "0,0,0,255", "outline_color": "255,255,255,255",
                   "outline_width": "0.1"}}],
        streets=None)
    scale(vmin, vmax)
    return len(shapes), vmin, vmax


def query4():
    """flightsQuery4.pdf: the number of aircraft in the air over the day, the steps of the
    temporal integer of tCount, with the peak marked."""
    text = pd.read_csv(f"{ANSWERS}/q4_series.csv").Aircraft[0]
    pairs = re.findall(r"(\d+)@([0-9-]+ [0-9:.]+)\+00", text)
    d = pd.DataFrame({"Aircraft": [int(v) for v, _ in pairs],
                      "Time": pd.to_datetime([t for _, t in pairs], format="ISO8601")})
    peak = d.loc[d.Aircraft.idxmax()]
    fig, ax = plt.subplots(figsize=(TEXTWIDTH, 1.9))
    ax.step(d.Time, d.Aircraft, where="post", color="#1f77b4", linewidth=0.6)
    ax.plot([peak.Time], [peak.Aircraft], "o", color="#d62728", markersize=2.5)
    # The label is centered below the peak, under the curve, which stays above it on both sides
    ax.annotate(f"{peak.Aircraft:,} at {peak.Time:%H:%M}", (peak.Time, peak.Aircraft),
                xytext=(0, -14), textcoords="offset points", ha="center", va="top",
                fontsize=7)
    ax.set_ylabel("Aircraft in the air")
    ax.set_xlabel("Time (UTC), March 1, 2026")
    ax.xaxis.set_major_locator(mdates.HourLocator(interval=2))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
    ax.set_xlim(pd.Timestamp("2026-03-01"), pd.Timestamp("2026-03-02"))
    ax.set_ylim(bottom=0)
    fig.tight_layout(pad=0.2)
    fig.savefig(f"{OUT}/flightsQuery4.pdf")
    return len(d), int(peak.Aircraft), f"{peak.Time:%H:%M:%S}"


def circle(lon, lat, radius, n=180):
    """The circle of the given radius in meters around a position on the WGS 84 spheroid."""
    geod = Geod(ellps="WGS84")
    pts = [geod.fwd(lon, lat, 360 * k / n, radius)[:2] for k in range(n)]
    return Polygon(pts)


def query5():
    rows = pd.read_csv(f"{ANSWERS}/q5_rows.csv")
    rows = rows[rows.WKT.notna()]
    features(f"{OUT}/flightsQuery5_trips.geojson",
             [(wkt.loads(w), {"color": rgba([int(c) for c in FIX_COLORS[f].split(",")] + [110])})
              for f, w in zip(rows.Fix, rows.WKT)])
    features(f"{OUT}/flightsQuery5_circles.geojson",
             [(circle(lon, lat, 15000), {}) for lon, lat in FIXES.values()])
    features(f"{OUT}/flightsQuery5_fixes.geojson",
             [(Point(lon, lat), {}) for lon, lat in FIXES.values()])
    # The height of the maps of Europe, 0.4 of the text height, its width that of the extent
    x0, x1, y0, y1 = extent = extent3857(-1.05, 0.70, 51.08, 51.98)
    job(OUT, "flightsQuery5", extent, 0.4 * TEXTHEIGHT * (x1 - x0) / (y1 - y0), [
        {"path": "flightsQuery5_trips.geojson", "kind": "line", "color_field": "color",
         "image": True, "style": {"line_color": "0,0,0,110", "line_width": "0.15"}},
        {"path": "flightsQuery5_circles.geojson", "kind": "fill",
         "style": {"color": "0,0,0,0", "outline_color": "0,0,0,255", "outline_width": "0.25",
                   "outline_style": "dash"}},
        {"path": "flightsQuery5_fixes.geojson", "kind": "marker",
         "style": {"name": "triangle", "color": "0,0,0,255", "outline_style": "no",
                   "size": "1.6"}}],
        streets="#ffffff", border="#9a9a9a")
    return len(rows)


def scale(vmin, vmax):
    """flightsQuery3_scale.tex: the logarithmic viridis scale of the distances under the map,
    with a tick labelled by each power of ten, in the style of the captions."""
    n = 8
    lines = ["% Written by flights_queries_maps.py: the color scale of flightsQuery3."]
    lines += ["\\definecolor{fqv%d}{rgb}{%.4f,%.4f,%.4f}" % (k, *VIRIDIS(k / n)[:3])
              for k in range(n + 1)]
    lines += ["\\begin{tikzpicture}[x=0.6\\textwidth, font=\\captionstyle]"]
    for k in range(n):
        lines.append("\\shade[left color=fqv%d, right color=fqv%d] (%.4f,0) rectangle (%.4f,3pt);"
                     % (k, k + 1, k / n, (k + 1) / n))
    lo, hi = round(math.log10(vmin)), round(math.log10(vmax))
    for e in range(lo, hi + 1):
        x = (e - lo) / (hi - lo)
        label = f"$10^{{{e}}}$"
        lines.append("\\draw[line width=0.2pt] (%.4f,0) -- ++(0,-1.5pt) "
                     "node[anchor=north, inner sep=1pt] {%s};" % (x, label))
    lines += ["\\node[anchor=west, inner sep=2pt] at (1,1.5pt) {km};", "\\end{tikzpicture}"]
    open(f"{OUT}/flightsQuery3_scale.tex", "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    ANSWERS, OUT = sys.argv[1], sys.argv[2]
    print("query 1: trajectories", query1())
    print("query 2: routes, destinations outside the map", query2())
    print("query 3: countries, scale", query3())
    print("query 4: instants, peak, peak time", query4())
    print("query 5: passes", query5())
