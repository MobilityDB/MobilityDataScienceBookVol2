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

"""Write the map panels of the flights dashboards 1 and 3 of the chapter Large-Scale Mobility Databases.

    python flights_maps.py <answers> <out>      then  render.sh <out>/<panel>.json

<answers> holds the answers of the panels as CSV, as the dashboards of chapter8/dashboards run
them: dashboard1.sql.0.csv (the positions of the flights leaving Brussels below 2,000 m while
they climb), dashboard3.sql.0.csv (the positions between 8 and 9 o'clock) and
dashboard3.sql.1.csv (those of the cruising flights). Each figure holds two panels side by
side, each a QGIS job (#job of mapjob.py) that qgis_map.py renders as a PDF of half the text
width: the Shortbread basemap of the book as one image of 300 dpi, and the positions with the
colors of the dashboards, viridis on the altitude. The 7,305 positions of dashboard 1 are
vectors; the 100,000 positions of a panel of dashboard 3 and the noise heat map of dashboard 1, a
density surface, are dense layers drawn as one image of 300 dpi. The panels carry no text: they
are the \\subfloat panels of their figure in chapter8.tex, each set by <panel>_overlay.tex with
the scale of its colors inside the map, its ticks and its title in the style of the captions.
Dashboard 3 draws, as the dashboard does, a sample of MAX_POINTS positions taken at random with
the seed 0 among those with a position and an altitude.
"""
import os
import sys

import numpy as np
import pandas as pd
from matplotlib import colormaps
from matplotlib.colors import LinearSegmentedColormap
from PIL import Image

from mapjob import TO3857, extent3857, job, points, rgba, size

ANSWERS, OUT = sys.argv[1], sys.argv[2]
TEXTWIDTH = 11.7 / 2.54          # inches
GAP = 0.2 / 2.54                 # inches between the two panels
PANEL = (TEXTWIDTH - GAP) / 2    # inches
# The positions a map of dashboard 3 draws at most (0: all), 100,000 as in the dashboard
MAX_POINTS = int(os.environ.get("MAX_POINTS", 100_000))
VIRIDIS = colormaps["viridis"]
# The color range of the HeatmapLayer of deck.gl (its default), transparent where nothing flies
HEAT = LinearSegmentedColormap.from_list("deckgl_heat", [
    (1.0, 1.0, 178 / 255, 0.0), (254 / 255, 217 / 255, 118 / 255, 0.55),
    (254 / 255, 178 / 255, 76 / 255, 0.7), (253 / 255, 141 / 255, 60 / 255, 0.8),
    (240 / 255, 59 / 255, 32 / 255, 0.85), (189 / 255, 0, 38 / 255, 0.9)])


def project(df):
    x, y = TO3857.transform(df["Lon"].values, df["Lat"].values)
    return df.assign(x=x, y=y)


def colors(values, vmax):
    return [rgba([round(255 * c) for c in VIRIDIS(v / vmax)[:3]])
            for v in np.clip(values, 0, vmax)]


def gaussian(grid, sigma):
    """grid convolved with a Gaussian of sigma cells, through the FFT."""
    ny, nx = grid.shape
    fy, fx = np.fft.fftfreq(ny)[:, None], np.fft.fftfreq(nx)[None, :]
    kernel = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(grid) * kernel))


def overlay(stem, corner, cmap, ticks, title):
    """<stem>_overlay.tex: the \\subfloat panel <stem>.pdf of its figure in chapter8.tex with the
    scale of its colors inside the map, in the corner (south east or north west) where no position
    lies, as chapter5/figures/overlay_bathymetry_laeso.py, a script without a function for it,
    sets the scale of its map: on a white box, the title, the colors of cmap (the viridis of
    #colors, or HEAT) in eight shaded segments, and below them the ticks, a list of (fraction of
    the bar, label or None), in the style of the captions."""
    n, length = 8, 2.4     # segments, centimeters
    name = stem.replace("_", "")
    lines = [f"% Written by flights_maps.py: the panel {stem} with the scale of its colors."]
    lines += ["\\definecolor{%sv%d}{rgb}{%.4f,%.4f,%.4f}%%" % (name, k, *cmap(k / n)[:3])
              for k in range(n + 1)]
    shift = {"south east": "shift={(img.south east)}, xshift=-%.2fcm, yshift=0.22cm"
                           % (length + 0.25),
             "north west": "shift={(img.north west)}, xshift=0.13cm, yshift=-0.92cm"}[corner]
    lines += ["\\begin{tikzpicture}",
              "\\node[anchor=south west, inner sep=0] (img) "
              f"{{\\includegraphics[width=0.49\\textwidth]{{figs/chap8/{stem}.pdf}}}};",
              f"\\begin{{scope}}[{shift}, font=\\captionstyle]",
              "\\fill[white, opacity=0.85] (-0.12, -0.14) rectangle (%.2f, 0.78);"
              % (length + 0.12),
              "\\node[anchor=south west, inner sep=0] at (0, 0.44) {%s};" % title]
    for k in range(n):
        lines.append("\\shade[left color=%sv%d, right color=%sv%d] "
                     "(%.3f, 0.28) rectangle (%.3f, 0.40);"
                     % (name, k, name, k + 1, length * k / n, length * (k + 1) / n))
    lines.append("\\draw[line width=0.2pt] (0, 0.28) rectangle (%.2f, 0.40);" % length)
    for f, label in ticks:
        anchor = "north west" if f == 0 else "north east" if f == 1 else "north"
        node = "" if label is None else " node[anchor=%s, inner sep=0.5pt] {%s}" % (anchor, label)
        lines.append("\\draw[line width=0.2pt] (%.3f, 0.28) -- ++(0, -0.04)%s;"
                     % (length * f, node))
    lines += ["\\end{scope}", "\\end{tikzpicture}%"]
    open(f"{OUT}/{stem}_overlay.tex", "w", encoding="utf-8").write("\n".join(lines) + "\n")


def altitude_ticks(top):
    """The ticks of #overlay for the altitudes from 0 to top meters: labels at both ends, and a
    tick without label at each quarter between them."""
    return [(q / 4, f"{q * top // 4:,}".replace(",", "\\,") if q in (0, 4) else None)
            for q in range(5)]


def heat_image(rows, extent, path):
    """The noise heat map as an RGBA PNG of 300 dpi of the panel, with its world file: the
    positions weighted by 2,000 m minus their altitude, smoothed with a Gaussian of 400 m, about
    the 30 pixels of the heat map of the dashboard at its zoom; the square root of the density,
    drawn above 5 % of its maximum as the threshold of deck.gl, keeps the weaker departures
    visible beside the runways."""
    x0, x1, y0, y1 = extent
    nx, ny = size(extent, PANEL)
    grid, _, _ = np.histogram2d(rows.y, rows.x, bins=(ny, nx), range=((y0, y1), (x0, x1)),
                                weights=2000 - rows["GeoAltitude"].clip(upper=2000))
    density = gaussian(grid, 400 / ((x1 - x0) / nx * np.cos(np.radians(50.85))))
    density = np.sqrt(np.clip(density / density.max(), 0, 1))
    rgba_ = (HEAT(density) * 255).astype(np.uint8)
    rgba_[density < 0.05, 3] = 0
    Image.fromarray(rgba_[::-1]).save(path)
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    open(path[:-4] + ".pgw", "w").write(f"{dx}\n0\n0\n{-dy}\n{x0 + dx / 2}\n{y1 - dy / 2}\n")


def dashboard1():
    rows = project(pd.read_csv(f"{ANSWERS}/dashboard1.sql.0.csv"))
    # The envelope of Brussels to which the query restricts the positions, longitude 4.25 to 4.60
    # and latitude 50.75 to 50.95, with a margin
    extent = extent3857(4.20, 4.65, 50.72, 50.98)
    heat_image(rows, extent, f"{OUT}/flightsDashboard1_heat.png")
    job(OUT, "flightsDashboard1_left", extent, PANEL, [
        {"type": "raster", "path": "flightsDashboard1_heat.png", "image": True}])
    points(f"{OUT}/flightsDashboard1_positions.geojson", rows.Lon, rows.Lat,
           colors(rows["GeoAltitude"], 2000))
    job(OUT, "flightsDashboard1_right", extent, PANEL, [
        {"path": "flightsDashboard1_positions.geojson", "kind": "marker", "color_field": "color",
         "style": {"name": "circle", "color": "0,0,0,255", "outline_style": "no", "size": "0.35"}}])
    overlay("flightsDashboard1_left", "south east", HEAT, [(0, "low"), (1, "high")], "Noise")
    overlay("flightsDashboard1_right", "south east", VIRIDIS, altitude_ticks(2000), "Altitude (m)")
    return len(rows), rows["ICAO24"].nunique()


def dashboard3():
    # Europe where its positions lie, longitude -20 to 40 and latitude 30 to 66, which leaves out
    # less than 1 % of the positions over the envelope of Europe, longitude -35.6 to 44.8 and
    # latitude 24.6 to 72 (0.94 % of those of the left panel, 0.73 % of the right one)
    extent = extent3857(-20.0, 40.0, 30.0, 66.0)
    counts = []
    for side, name in (("left", "dashboard3.sql.0.csv"), ("right", "dashboard3.sql.1.csv")):
        rows = pd.read_csv(f"{ANSWERS}/{name}").dropna(subset=["Lon", "Lat", "Altitude"])
        shown = rows.sample(n=MAX_POINTS, random_state=0) if 0 < MAX_POINTS < len(rows) else rows
        stem = f"flightsDashboard3_{side}"
        points(f"{OUT}/{stem}_positions.geojson", shown.Lon, shown.Lat,
               colors(shown["Altitude"], 12000))
        job(OUT, stem, extent, PANEL, [
            {"path": f"{stem}_positions.geojson", "kind": "marker", "color_field": "color",
             "image": True,
             "style": {"name": "circle", "color": "0,0,0,255", "outline_style": "no", "size": "0.12"}}],
            streets=None, border="#9a9a9a")
        overlay(stem, "north west", VIRIDIS, altitude_ticks(12000), "Altitude (m)")
        counts.append((name, len(rows), len(shown)))
    return counts


if __name__ == "__main__":
    print("dashboard 1: positions, aircraft", dashboard1())
    print("dashboard 3: file, drawable, drawn", dashboard3())
