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

"""Write the maps of the moving regions of Sect. 3.1 with a scale bar each, so
that the reader compares their scales: Fig. 3.3 (the noise region of an hour),
Fig. 3.4 (the hull turning in a harbor), and Figs. 3.5a and 3.5b (ten seconds
and the whole line of a survey), and Fig. 3.18 (the four temporal types over
the ten seconds, its extent that of job_pcl_compare.json). Each map is a TikZ picture of the image at
its printed width, with a bar of a round length in a white box in a corner the
map leaves empty, in the style of the scale bars of overlay_excerpt.py (Fig.
3.17). The bar is a fraction of the width of the image, the length of the bar
over the ground width of the map, so that it does not depend on the width of
the text.

The ground widths: Fig. 3.3 is in EPSG:25832, and noise_width() repeats the
extent of noise_region_job.py (its PAD and ASPECT): the box of the traversed
area of the hour, 13,249.9 x 7,421.0 m, with a margin of 8% widened to the
aspect 1.6. Fig. 3.4 is in EPSG:3857, the extent of job_hull.json, and
mercator_width() takes the ground width of that extent at the latitude of its
center. Figs. 3.5a, 3.5b and 3.18 are in EPSG:25832, the widths of
job_pcl_swath.json, job_pcl_line.json and job_pcl_compare.json.

    python3 scalebars.py <dir> <outdir>

<dir> is the directory of the images as the book includes them, figs/chap3.
"""
import math
import os
import sys

imgdir, outdir = sys.argv[1:3]
R = 6378137.0


def noise_width():
    w, h = 13249.930 * 1.16, 7420.985 * 1.16
    return max(w, h * 1.6)


def mercator_width(x0, y0, x1, y1):
    lat = 2 * math.atan(math.exp((y0 + y1) / 2 / R)) - math.pi / 2
    return (x1 - x0) * math.cos(lat)


# The file written, the image, its printed width, its ground width in meters, the bar in
# meters, its label, and the corner of the bar
MAPS = [
    ("ais_noise_region_scaled", "ais_noise_region.pdf", "0.9\\textwidth", noise_width(),
     2000, "2 km", "west"),
    ("ais_hull_turn_scaled", "ais_hull_turn.pdf", "0.9\\textwidth",
     mercator_width(1316330.5429797755, 7900694.2195336325, 1319173.9862796874,
                    7902471.371596078), 200, "200 m", "east"),
    ("pointcloud_swath_scaled", "pointcloud_swath.pdf", "0.443\\textwidth",
     703018.39 - 702969.66, 10, "10 m", "east"),
    ("pointcloud_line_scaled", "pointcloud_line.pdf", "0.527\\textwidth",
     703049.3 - 702786.3, 50, "50 m", "west"),
    ("pointcloud_compare_scaled", "pointcloud_compare.pdf", "0.9\\textwidth",
     703037.2 - 702950.8, 10, "10 m", "east"),
]
for name, image, width, ground, meters, label, corner in MAPS:
    f = meters / ground
    # The bar starts 4% of the width from its side of the map
    a, b = (0.04, 0.04 + f) if corner == "west" else (0.96 - f, 0.96)
    lines = [
        "%% Written by scalebars.py: a bar of %s on a map %.1f m wide." % (label, ground),
        "\\begin{tikzpicture}[font=\\captionstyle]",
        "\\node[anchor=south west, inner sep=0] (p) {\\includegraphics[width=%s]{%s/%s}};"
        % (width, imgdir, image),
        "\\coordinate (a) at ($(p.south west)!%.4f!(p.south east) + (0, 0.25)$);" % a,
        "\\coordinate (b) at ($(p.south west)!%.4f!(p.south east) + (0, 0.25)$);" % b,
        "\\fill[white, opacity=0.9] ($(a) + (-0.1, -0.12)$) rectangle ($(b) + (0.1, 0.5)$);",
        "\\draw[line width=0.4pt] ($(a) + (0, 0.06)$) -- (a) -- (b) -- ($(b) + (0, 0.06)$);",
        "\\node[anchor=south, inner sep=1pt] at ($(a)!0.5!(b) + (0, 0.06)$) {%s};" % label,
        "\\end{tikzpicture}",
    ]
    out = os.path.join(outdir, name + ".tex")
    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("wrote", out, "bar %.3f of the width" % f)
