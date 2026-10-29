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

"""Write the LaTeX body of Fig. 3.18, what four temporal types of the survey
vessel of Fig. 3.5 cover over its ten seconds: the trajectory of its antenna
(tgeompoint), the traversed area of the vessel as a temporal circular buffer
(tcbuffer) and as a temporal rigid geometry (trgeometry), and the swath of its
pings (tpcpatch). The map, rendered from job_pcl_compare.json, carries the
scale bar of scalebars.py, and the legend below it names each type, set in the style of the captions of
the book (\\captionstyle), with the notation of Fig. 3.17.

    python3 overlay_pcl.py <dir> <out.tex>
"""
import sys

imgdir, out = sys.argv[1:3]
brown = "{rgb,255:red,122;green,61;blue,0}"
lines = [
    "% Written by overlay_pcl.py.",
    "\\definecolor{tablue}{RGB}{170,200,255}",
    "\\definecolor{taorange}{RGB}{220,145,79}",
    "\\input{%s/pointcloud_compare_scaled}" % imgdir,
    "",
    "\\medskip",
    "\\begin{tikzpicture}[font=\\captionstyle]",
    "\\draw[blue, line width=0.6pt] (0, 0) -- (0.47, 0);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, 0) {\\textsf{tgeompoint}: trajectory of the antenna};",
    "\\draw[blue, line width=0.6pt, dashed] (0, -0.6) rectangle (0.47, -0.42);",
    "\\node[anchor=west, inner sep=1pt] at (0.55, -0.51) {\\textsf{tcbuffer}: traversed area};",
    "\\fill[taorange, draw=%s, line width=0.3pt] (6.0, -0.09) rectangle (6.47, 0.09);" % brown,
    "\\node[anchor=west, inner sep=1pt] at (6.55, 0) {\\textsf{trgeometry}: traversed area};",
    "\\fill[tablue, draw=blue, line width=0.3pt] (6.0, -0.6) rectangle (6.47, -0.42);",
    "\\node[anchor=west, inner sep=1pt] at (6.55, -0.51) {\\textsf{tpcpatch}: swath};",
    "\\end{tikzpicture}",
]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out)
