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

"""Write the LaTeX overlay of the figure of the bathymetry around Laeso: the
image rendered from job_bathymetry_laeso.json, the names of the two protected
areas at their positions, and the legend of the depth ramp, the text set in the
style of the captions of the book (\\captionstyle), so that the figure and its
caption share their font and their size. The legend is the one of
overlay_depth_under_vessel.py, in the same box in the lower-right corner.

    python3 overlay_bathymetry_laeso.py <job.json> <image> <width> <out.tex>

<image> is the path of the image as the book includes it, <width> its width
in the book, for instance 0.85\\textwidth.
"""
import json
import sys

job_path, image, width, out = sys.argv[1:5]
job = json.load(open(job_path, encoding="utf-8"))
xmin, ymin, xmax, ymax = job["extent"]
ramp = job["legend_ramp"]

vmin, vmax = ramp[0][0], ramp[-1][0]
lines = ["% Written by overlay_bathymetry_laeso.py from the job."]
lines += ["\\definecolor{c%d}{HTML}{%s}" % (i, c.lstrip("#").upper())
          for i, (_, c) in enumerate(ramp)]
lines += ["\\definecolor{l%d}{HTML}{%s}" % (i, lb["color"].lstrip("#").upper())
          for i, lb in enumerate(job["labels"])]
lines += [
    "\\begin{tikzpicture}",
    "\\node[anchor=south west, inner sep=0] (img) "
    "{\\includegraphics[width=%s]{%s}};" % (width, image),
    "\\begin{scope}[x={(img.south east)}, y={(img.north west)}, font=\\captionstyle]",
]
# Each name centred at its position, given in the coordinates of the map, on a
# white box of the opacity of the legend, since a name lies over the shallow water
for i, lb in enumerate(job["labels"]):
    fx = (lb["x"] - xmin) / (xmax - xmin)
    fy = (lb["y"] - ymin) / (ymax - ymin)
    lines.append("\\node[inner sep=1pt, fill=white, fill opacity=0.85, text opacity=1, text=l%d] "
                 "at (%.4f, %.4f) {%s};" % (i, fx, fy, lb["text"]))
lines.append("\\end{scope}")
# The legend: the ramp as a horizontal shading, its ticks, and its title, in a
# white box as large as its content, in the lower-right corner of the image.
lines += [
    "\\begin{scope}[shift={(img.south east)}, xshift=-3.35cm, yshift=0.22cm, font=\\captionstyle]",
    "\\fill[white, opacity=0.85] (-0.12, -0.14) rectangle (3.2, 0.78);",
    "\\node[anchor=south west, inner sep=0] at (0, 0.44) {Depth (m)};",
]
# One left-to-right shading per pair of consecutive stops of the ramp.
for i in range(len(ramp) - 1):
    x0 = (ramp[i][0] - vmin) / (vmax - vmin) * 3.0
    x1 = (ramp[i + 1][0] - vmin) / (vmax - vmin) * 3.0
    lines.append("\\shade[left color=c%d, right color=c%d] (%.3f, 0.28) rectangle (%.3f, 0.40);"
                 % (i, i + 1, x0, x1))
lines.append("\\draw[line width=0.2pt] (0, 0.28) rectangle (3.0, 0.40);")
for t in job["legend_ticks"]:
    x = (t - vmin) / (vmax - vmin) * 3.0
    lines.append("\\draw[line width=0.2pt] (%.3f, 0.28) -- ++(0, -0.04) "
                 "node[anchor=north, inner sep=0.5pt] {%s};" % (x, t))
lines += ["\\end{scope}", "\\end{tikzpicture}"]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out, len(job["labels"]), "labels")
