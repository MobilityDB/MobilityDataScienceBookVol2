"""The figures of dashboard 2 of the flights use case of chapter 8, from the answers of MobilityDB.

    python flights_dashboard2_maps.py <answers> <out> <lon> <lat> <name1> <name2>
    then  render.sh <out> flightsDashboard2_map.json

<answers> holds d2_distance.csv (Time, Distance in km), d2_positions.csv (Time, Aircraft, Lat,
Lon, GeoAltitude) and d2_altitude.csv (Time, Aircraft, GeoAltitude), which flights_dashboard2.sql
writes; <lon> <lat> is the place of the nearest approach (the point p1 that its first query
prints) and <name1> <name2> are the call signs of the aircraft 1 and 2, the titles of the
panels of the altitudes. It writes flightsDashboard2_distance.pdf (the distance over time),
flightsDashboard2_altitude.pdf (the altitude of each aircraft over time) as vector charts in
Latin Modern, the font of the book, and the QGIS job flightsDashboard2_map.json (the position
reports of the two aircraft over the Shortbread basemap), which render.sh renders.
"""
import sys

import matplotlib
matplotlib.use("pgf")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd
from matplotlib import font_manager

from mapjob import TO3857, geometry, job, padded, points  # noqa: E402

ANSWERS, OUT = sys.argv[1], sys.argv[2]
NA_LON, NA_LAT = float(sys.argv[3]), float(sys.argv[4])
TEXTWIDTH = 11.7 / 2.54
GAP = 0.2 / 2.54
PANEL = (TEXTWIDTH - GAP) / 2
# The map of panel (a) takes 0.55 of the text width and the altitudes of panel (b), in km so that
# their axis is narrow, 0.43 of it, at the height of the map
MAP_W = 0.55 * TEXTWIDTH
CHART_W = 0.43 * TEXTWIDTH
COLORS = {1: "#d62728", 2: "#1f77b4"}
for f in ("lmroman10-regular.otf", "lmroman10-bold.otf"):
    font_manager.fontManager.addfont(f"/usr/share/texmf/fonts/opentype/public/lm/{f}")
plt.rcParams.update({"pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
                     "font.family": "serif", "font.size": 8,
                     "axes.linewidth": 0.5, "xtick.major.width": 0.5, "ytick.major.width": 0.5,
                     "axes.spines.top": False, "axes.spines.right": False})
HOURS = mdates.DateFormatter("%H:%M")


def times(df):
    df = df.rename(columns=str.title).rename(columns={"Geoaltitude": "GeoAltitude"})
    return df.assign(Time=pd.to_datetime(df["Time"], utc=True, format="ISO8601").dt.tz_convert(None))


def distance():
    d = times(pd.read_csv(f"{ANSWERS}/d2_distance.csv"))
    fig, ax = plt.subplots(figsize=(TEXTWIDTH, 1.9))
    ax.plot(d.Time, d.Distance, color="#1f77b4", linewidth=0.7)
    ax.set_yscale("log")
    # The axis keeps only the ticks of the powers of 10 that carry their label
    ax.yaxis.set_minor_locator(mticker.NullLocator())
    ax.set_ylabel("Distance (km)")
    ax.set_xlabel("Time (UTC), March 1, 2026")
    ax.xaxis.set_major_formatter(HOURS)
    fig.tight_layout(pad=0.2)
    fig.savefig(f"{OUT}/flightsDashboard2_distance.pdf")
    return len(d)


def altitude(names):
    a = times(pd.read_csv(f"{ANSWERS}/d2_altitude.csv"))
    fig, axes = plt.subplots(2, 1, figsize=(CHART_W, MAP_W), sharex=True)
    for ax, k in zip(axes, (1, 2)):
        r = a[a.Aircraft == k].dropna(subset=["GeoAltitude"])
        ax.plot(r.Time, r.GeoAltitude / 1000, ".", color=COLORS[k], markersize=1.2,
                markeredgewidth=0)
        ax.set_title(names[k], fontsize=8, loc="left", pad=2)
        ax.set_ylabel("Altitude (km)")
        ax.xaxis.set_major_locator(mdates.HourLocator())
        ax.xaxis.set_major_formatter(HOURS)
    axes[1].set_xlabel("Time (UTC)")
    fig.tight_layout(pad=0.2, h_pad=1.6)
    fig.savefig(f"{OUT}/flightsDashboard2_altitude.pdf")
    return {k: int((a.Aircraft == k).sum()) for k in (1, 2)}


def mapjob():
    p = pd.read_csv(f"{ANSWERS}/d2_positions.csv").rename(columns=str.title)
    x, y = TO3857.transform(p.Lon.values, p.Lat.values)
    x0, x1, y0, y1 = padded(x, y, 60_000)
    # A square map of the panel width, centered on the two tracks
    cx, cy, half = (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) / 2
    extent = (cx - half, cx + half, cy - half, cy + half)
    layers = []
    for k in (1, 2):
        r = p[p.Aircraft == k]
        geometry(f"{OUT}/flightsDashboard2_track{k}.geojson",
                 {"type": "LineString", "coordinates": r[["Lon", "Lat"]].values.tolist()})
        points(f"{OUT}/flightsDashboard2_reports{k}.geojson", r.Lon, r.Lat)
        rgb = ",".join(str(int(COLORS[k][i:i + 2], 16)) for i in (1, 3, 5))
        layers += [
            {"path": f"flightsDashboard2_track{k}.geojson", "kind": "line",
             "style": {"color": rgb + ",255", "width": "0.25"}},
            {"path": f"flightsDashboard2_reports{k}.geojson", "kind": "marker",
             "style": {"name": "circle", "color": rgb + ",255", "outline_style": "no",
                       "size": "0.5"}}]
    points(f"{OUT}/flightsDashboard2_approach.geojson", [NA_LON], [NA_LAT])
    layers.append({"path": "flightsDashboard2_approach.geojson", "kind": "marker",
                   "style": {"name": "circle", "color": "255,255,255,0",
                             "outline_color": "0,0,0,255", "outline_width": "0.3",
                             "size": "2.2"}})
    job(OUT, "flightsDashboard2_map", extent, MAP_W, layers, streets=None, border="#9a9a9a")
    return {k: int((p.Aircraft == k).sum()) for k in (1, 2)}


if __name__ == "__main__":
    names = {1: sys.argv[5], 2: sys.argv[6]}
    print("distance rows", distance())
    print("altitude rows", altitude(names))
    print("position rows", mapjob())
