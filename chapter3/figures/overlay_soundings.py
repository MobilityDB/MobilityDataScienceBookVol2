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

"""Write the LaTeX overlay of the figure of the multibeam surveys off Rostock:
the overview and the close-up rendered by render.sh of chapter5/figures from
job_soundings_overview.json and job_soundings_closeup.json side by side, with
the day of each survey line beside the start of its trip, the legend of the
topography ramp, the legend of the soundings of the two surveys, and a scale
bar in each panel, the text set in the style of the captions of the book
(\\captionstyle), so that the figure and its caption share their font and their
size. It follows overlay_depth_under_vessel.py of chapter5/figures.

    python3 overlay_soundings.py <overview.json> <closeup.json> <trips.gpkg> <dir> <out.tex>

<dir> is the directory of the two images as the book includes them, for
instance figs/chap5.
"""
import json
import sys

from osgeo import ogr

over_path, close_path, trips_path, imgdir, out = sys.argv[1:6]
over = json.load(open(over_path, encoding="utf-8"))
close = json.load(open(close_path, encoding="utf-8"))
xmin, ymin, xmax, ymax = over["extent"]
ramp = over["legend_ramp"]
# Both panels have the height of the overview, whose width follows from its size.
height = 7.0
over_w = height * over["size"][0] / over["size"][1]
close_w = height * close["size"][0] / close["size"][1]

# The label of a line is placed at the end of its trip farther from the square,
# read from the layer, above it when it is the northern end and below it
# otherwise.
names = {"20190514": "May 14", "20191022": "October 22"}
cx, cy = 702995, 6008577
labels = []
ds = ogr.Open(trips_path)
for f in ds.GetLayer(0):
    g = f.GetGeometryRef()
    ends = [g.GetPoint_2D(0), g.GetPoint_2D(g.GetPointCount() - 1)]
    x, y = max(ends, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
    labels.append((names[f.GetField("day")], (x - xmin) / (xmax - xmin),
                   (y - ymin) / (ymax - ymin), y > max(e[1] for e in ends) - 1))

vmin, vmax = ramp[0][0], ramp[-1][0]
lines = ["% Written by overlay_soundings.py from the jobs and the trips."]
lines += ["\\definecolor{c%d}{HTML}{%s}" % (i, c.lstrip("#").upper())
          for i, (_, c) in enumerate(ramp)]
lines += [
    "\\definecolor{may}{HTML}{2166AC}",
    "\\definecolor{october}{HTML}{D7301F}",
    "\\begin{tikzpicture}",
    "\\node[anchor=south west, inner sep=0] (a) "
    "{\\includegraphics[height=%.2fcm]{%s/soundings_overview}};" % (height, imgdir),
    "\\node[anchor=south west, inner sep=0] (b) at ([xshift=0.6cm]a.south east) "
    "{\\includegraphics[height=%.2fcm]{%s/soundings_closeup}};" % (height, imgdir),
    "\\draw[line width=0.2pt] (b.south west) rectangle (b.north east);",
    "\\begin{scope}[shift={(a.south west)}, x={(a.south east)}, y={(a.north west)}, "
    "font=\\captionstyle]",
]
for text, fx, fy, north in sorted(labels):
    lines.append("\\node[anchor=%s, inner sep=1pt, fill=white, fill opacity=0.85, "
                 "text opacity=1] at (%.4f, %.4f) {%s};"
                 % ("south" if north else "north", fx, fy, text))
lines.append("\\end{scope}")
# The legend of the topography: the ramp as a vertical shading with its ticks and
# its title, in the empty left part of the overview, between the two lines.
lines += [
    "\\begin{scope}[shift={(a.north west)}, xshift=0.1cm, yshift=-3.2cm, font=\\captionstyle]",
    "\\node[anchor=south west, inner sep=0, align=left] at (0, 2.25) {Topography\\\\(m)};",
]
for i in range(len(ramp) - 1):
    y0 = (ramp[i][0] - vmin) / (vmax - vmin) * 2.0
    y1 = (ramp[i + 1][0] - vmin) / (vmax - vmin) * 2.0
    lines.append("\\shade[bottom color=c%d, top color=c%d] (0, %.3f) rectangle (0.18, %.3f);"
                 % (i, i + 1, y0, y1))
lines.append("\\draw[line width=0.2pt] (0, 0) rectangle (0.18, 2.0);")
for t in over["legend_ticks"]:
    y = (t - vmin) / (vmax - vmin) * 2.0
    lines.append("\\draw[line width=0.2pt] (0.18, %.3f) -- ++(0.04, 0) "
                 "node[anchor=west, inner sep=1pt] {$%d$};" % (y, t))
lines.append("\\end{scope}")
# The scale bar of the overview, 100 m, in its lower-left corner.
bar = 100 / (xmax - xmin) * over_w
lines += [
    "\\begin{scope}[shift={(a.south west)}, xshift=0.1cm, yshift=0.25cm, font=\\captionstyle]",
    "\\draw[line width=0.4pt] (0, 0.06) -- (0, 0) -- (%.3f, 0) -- (%.3f, 0.06);" % (bar, bar),
    "\\node[anchor=south, inner sep=1pt] at (%.3f, 0.06) {100 m};" % (bar / 2),
    "\\end{scope}",
]
# The legend of the close-up and its scale bar, 1 m, in white boxes.
cx0, _, cx1, _ = close["extent"]
cbar = 1 / (cx1 - cx0) * close_w
lines += [
    "\\begin{scope}[shift={(b.north east)}, xshift=-2.3cm, yshift=-0.85cm, font=\\captionstyle]",
    "\\fill[white, opacity=0.9] (-0.1, -0.1) rectangle (2.2, 0.75);",
    "\\fill[may] (0.08, 0.5) circle (0.05);",
    "\\node[anchor=west, inner sep=1pt] at (0.2, 0.5) {May 14};",
    "\\fill[october] (0.08, 0.15) circle (0.05);",
    "\\node[anchor=west, inner sep=1pt] at (0.2, 0.15) {October 22};",
    "\\end{scope}",
    "\\begin{scope}[shift={(b.south west)}, xshift=0.2cm, yshift=0.25cm, font=\\captionstyle]",
    "\\fill[white, opacity=0.9] (-0.1, -0.1) rectangle (%.3f, 0.5);" % (cbar + 0.1),
    "\\draw[line width=0.4pt] (0, 0.06) -- (0, 0) -- (%.3f, 0) -- (%.3f, 0.06);" % (cbar, cbar),
    "\\node[anchor=south, inner sep=1pt] at (%.3f, 0.06) {1 m};" % (cbar / 2),
    "\\end{scope}",
    "\\node[anchor=north, font=\\captionstyle] at (a.south) {(a)};",
    "\\node[anchor=north, font=\\captionstyle] at (b.south) {(b)};",
    "\\end{tikzpicture}",
]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out, len(labels), "lines")
