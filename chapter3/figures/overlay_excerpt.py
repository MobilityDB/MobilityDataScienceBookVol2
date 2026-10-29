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

"""Write the LaTeX body of the figure that compares, over an excerpt of a
survey line, the traversed area of the vessel as a temporal rigid geometry and
as a temporal circular buffer: two subfloats side by side, each captioned with
its type, its function, and the area it answers, each with a scale bar of 5
meters in a corner the regions leave empty, and a legend below the subfloats,
in the style of the captions of the book (\\captionstyle) and with the
notation of Figs. 3.4 and 3.15; Fig. 3.5a shows the swath of the same excerpt. Each
panel is drawn from job_excerpt_<panel>.json of <jobdir>, whose extent sets
the length of its scale bar. It follows overlay_soundings.py.

    python3 overlay_excerpt.py <jobdir> <dir> <area_rigid> <area_buffer> <out.tex>
"""
import json
import os
import sys

jobdir, imgdir, a_rigid, a_buffer, out = sys.argv[1:6]
side = 5.4
ramp = ["F6DCAE", "EEC48C", "E5AA6C", "DC914F", "D07836", "C25F1E"]
# The panel, its caption, the corner of its scale bar, and its length in meters
panels = [
    ("rigid", "\\textsf{trgeometry}: \\textsf{traversedArea}, %s m$^2$" % a_rigid, "west", 5),
    ("buffer", "\\textsf{tcbuffer}: \\textsf{traversedArea}, %s m$^2$" % a_buffer, "west", 5),
]
lines = ["% Written by overlay_excerpt.py from the jobs and the areas."]
lines += ["\\definecolor{r%d}{HTML}{%s}" % (i, c) for i, c in enumerate(ramp)]
lines.append("\\definecolor{tablue}{RGB}{170,200,255}")
for i, (name, caption, corner, meters) in enumerate(panels):
    job = json.load(open(os.path.join(jobdir, "job_excerpt_%s.json" % name), encoding="utf-8"))
    x0, _, x1, _ = job["extent"]
    bar = meters / (x1 - x0) * side
    left = 0.25 if corner == "west" else side - 0.25 - bar
    lines += [
        "\\subfloat[%s]{\\label{fig:tess_excerpt_%s}%%" % (caption, "ab"[i]),
        "\\begin{tikzpicture}[font=\\captionstyle]",
        "\\node[anchor=south west, inner sep=0] (p) {\\includegraphics[width=%.2fcm]{%s/excerpt_%s}};"
        % (side, imgdir, name),
        "\\draw[line width=0.2pt] (p.south west) rectangle (p.north east);",
        "\\fill[white, opacity=0.9] (%.3f, 0.13) rectangle (%.3f, 0.75);" % (left - 0.1, left + bar + 0.1),
        "\\draw[line width=0.4pt] (%.3f, 0.31) -- (%.3f, 0.25) -- (%.3f, 0.25) -- (%.3f, 0.31);"
        % (left, left, left + bar, left + bar),
        "\\node[anchor=south, inner sep=1pt] at (%.3f, 0.31) {%d m};" % (left + bar / 2, meters),
        "\\end{tikzpicture}}%s" % ("\\hfill" if i == 0 else ""),
    ]
# The legend, below the two subfloats
lines += ["", "\\medskip", "\\begin{tikzpicture}[font=\\captionstyle]"]
for i in range(6):
    lines.append("\\fill[r%d, draw={rgb,255:red,122;green,61;blue,0}, line width=0.3pt] "
                 "(%.2f, -0.09) rectangle (%.2f, 0.09);" % (i, 0.25 * i, 0.25 * i + 0.22))
lines += [
    "\\node[anchor=west, inner sep=1pt] at (1.55, 0) {Values every 2 s from 08:54:50 to 08:55:00};",
    "\\fill[tablue, draw=blue, line width=0.3pt] (0, -0.6) rectangle (0.47, -0.42);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, -0.51) {Traversed area};",
    "\\draw[blue, line width=0.6pt] (6.0, -0.51) -- (6.47, -0.51);",
    "\\node[anchor=west, inner sep=1pt] at (6.55, -0.51) {Track of the antenna};",
    "\\end{tikzpicture}",
]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out)
