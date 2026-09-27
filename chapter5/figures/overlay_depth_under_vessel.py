"""Write the LaTeX overlay of the figure of the depth under the vessel: the
image rendered by render.sh from job_depth_under_vessel.json, the time of each
report beside its dot, and the legend of the depth ramp, the text set in the
style of the captions of the book (\\captionstyle), so that the figure and its
caption share their font and their size.

    python3 overlay_depth_under_vessel.py <job.json> <vessel_reports.gpkg> <image> <width> <out.tex>

<image> is the path of the image as the book includes it, <width> its width
in the book, for instance 0.85\\textwidth.
"""
import json
import sys

from osgeo import ogr

job_path, reports_path, image, width, out = sys.argv[1:6]
job = json.load(open(job_path, encoding="utf-8"))
xmin, ymin, xmax, ymax = job["extent"]
ramp = job["legend_ramp"]

ds = ogr.Open(reports_path)
layer = ds.GetLayer(0)
reports = []
for f in layer:
    g = f.GetGeometryRef()
    fx = (g.GetX() - xmin) / (xmax - xmin)
    fy = (g.GetY() - ymin) / (ymax - ymin)
    if 0 <= fx <= 1 and 0 <= fy <= 1:
        reports.append((f.GetField("label")[3:], fx, fy))

vmin, vmax = ramp[0][0], ramp[-1][0]
lines = ["% Written by overlay_depth_under_vessel.py from the job and the reports."]
lines += ["\\definecolor{c%d}{HTML}{%s}" % (i, c.lstrip("#").upper())
          for i, (_, c) in enumerate(ramp)]
lines += [
    "\\begin{tikzpicture}",
    "\\node[anchor=south west, inner sep=0] (img) "
    "{\\includegraphics[width=%s]{%s}};" % (width, image),
    "\\begin{scope}[x={(img.south east)}, y={(img.north west)}, font=\\captionstyle]",
]
for text, fx, fy in sorted(reports):
    lines.append("\\node[anchor=north west, inner sep=0.5pt] at (%.4f, %.4f) "
                 "{%s};" % (fx + 0.006, fy - 0.008, text))
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
print("wrote", out, len(reports), "reports")
