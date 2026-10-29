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

"""Write the LaTeX overlay of the figure of the surveyed area and the vessels
of the day: the image rendered by render.sh from job_soundings_context.json,
the legend of its three kinds of lines, and a scale bar, the text set in the
style of the captions of the book (\\captionstyle). It follows
overlay_soundings.py.

    python3 overlay_soundings_context.py <job.json> <image> <width> <out.tex>

<image> is the path of the image as the book includes it, <width> its width
in the book, for instance 0.6\\textwidth.
"""
import json
import re
import sys

job_path, image, width, out = sys.argv[1:5]
job = json.load(open(job_path, encoding="utf-8"))
xmin, _, xmax, _ = job["extent"]
# The width in centimeters of the image as printed, from the width in the book
frac = float(re.match(r"([0-9.]+)", width).group(1))
img_w = frac * 11.7
bar = 500 / (xmax - xmin) * img_w
lines = [
    "% Written by overlay_soundings_context.py from the job.",
    "\\begin{tikzpicture}",
    "\\node[anchor=south west, inner sep=0] (img) {\\includegraphics[width=%s]{%s}};"
    % (width, image),
    "\\begin{scope}[shift={(img.north west)}, xshift=0.15cm, yshift=-1.25cm, font=\\captionstyle]",
    "\\fill[white, opacity=0.9] (-0.1, -0.12) rectangle (3.9, 1.05);",
    "\\draw[color={rgb,255:red,150;green,150;blue,150}, line width=0.6pt] (0, 0.85) -- (0.45, 0.85);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, 0.85) {Trips within 1 km};",
    "\\draw[color={rgb,255:red,215;green,48;blue,31}, line width=0.8pt] (0, 0.5) rectangle (0.45, 0.62);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, 0.53) {Surveyed area};",
    "\\draw[color={rgb,255:red,37;green,37;blue,37}, line width=0.8pt] (0, 0.15) -- (0.45, 0.15);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, 0.15) {Survey lines};",
    "\\end{scope}",
    "\\begin{scope}[shift={(img.south west)}, xshift=0.25cm, yshift=0.3cm, font=\\captionstyle]",
    "\\fill[white, opacity=0.9] (-0.1, -0.12) rectangle (%.3f, 0.5);" % (bar + 0.1),
    "\\draw[line width=0.4pt] (0, 0.06) -- (0, 0) -- (%.3f, 0) -- (%.3f, 0.06);" % (bar, bar),
    "\\node[anchor=south, inner sep=1pt] at (%.3f, 0.06) {500 m};" % (bar / 2),
    "\\end{scope}",
    "\\end{tikzpicture}",
]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out)
