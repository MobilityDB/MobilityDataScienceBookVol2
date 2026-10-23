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

"""Draw the figures of the errors of the use case of chapter 11, at the printed size of the book
(widths in fractions of \\textwidth, included unscaled) and with the text in the face of the captions
(LM Roman at 8 pt, through the PGF backend and pdflatex):

    errors_paired.pdf        the mean of the paired differences of the error per window between
                             crossdomain and linear and between crossdomain and coordinates, by task
                             and by the speed class of the vessel (below 0.5 knots, 0.5 to 3, 3 or
                             more), with its 95% interval from a paired bootstrap of 2,000 samples
                             of windows, and the share of windows in which crossdomain is better;
    errors_isolation.pdf     the median recovery error against the isolation, and
    errors_horizon.pdf       the median prediction error against the horizon, for the windows of
                             vessels at 3 knots or more;
    errors_q14_gap5452.pdf   the gap 5452, the region the vessel can reach during it at 30 knots,
                             the reconstructed path, and the protected areas that the region excludes,
                             that it admits, and that the path enters.

    psql -d ais -f export_errors.sql
    python3 curves.py
    python3 fig_errors.py

The CSV files are read from the working directory, where the figures are written; paired_rows.txt
and curve_points.txt list the values drawn in the first three figures.
"""
import csv, math, random, statistics as st
from collections import defaultdict
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch, Ellipse, Circle
from shapely import wkt
from shapely.geometry import box

plt.rcParams.update({"pgf.texsystem": "pdflatex", "pgf.rcfonts": False, "font.family": "serif",
                     "font.size": 8, "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
                     "axes.linewidth": 0.6, "xtick.major.width": 0.6, "ytick.major.width": 0.6,
                     "xtick.major.size": 2.5, "ytick.major.size": 2.5, "legend.fontsize": 8})
TW = 332.89723 / 72.27
BLUE, RED, ORANGE, GRAY, INK, MUTED = "#1f77b4", "#d62728", "#e8820c", "#9a9a9a", "#222222", "#555555"
MODEL_STYLE = {"linear": dict(color=INK, marker="s", ls="-"),
               "coordinates": dict(color=BLUE, marker="o", ls="--"),
               "crossdomain": dict(color=ORANGE, marker="o", ls="-")}

kn = {int(r['gapid']): float(r['kn'] or 0) for r in csv.DictReader(open('winspeed.csv'))}
def cls(g): k = kn[g]; return 'still' if k < 0.5 else ('slow' if k < 3 else 'moving')
pw = defaultdict(dict)
for r in csv.DictReader(open('perwindow.csv')): pw[(r['task'], int(r['gapid']))][r['model']] = float(r['err'])
random.seed(1)
def boot(d, n=2000):
    m = sorted(st.mean(random.choices(d, k=len(d))) for _ in range(n)); return m[int(.025 * n)], m[int(.975 * n)]

def save(fig, name):
    # tight box, included at natural size by the chapter, so the 8 pt text is never rescaled
    fig.savefig(f"{name}.pdf", backend="pgf", bbox_inches="tight", pad_inches=0.06)

# ---- paired differences per window, by speed class
CLASSES = (("still", "below 0.5 kn"), ("slow", "0.5 to 3 kn"), ("moving", "3 kn or more"), ("all", "all windows"))
def paired_rows(a, b):
    rows = []
    for task in ("recovery", "prediction"):
        for c, lab in CLASSES:
            d = [v[a] - v[b] for (t, g), v in pw.items() if t == task and a in v and b in v and (c == 'all' or cls(g) == c)]
            lo, hi = boot(d)
            rows.append((task, lab, len(d), st.mean(d), lo, hi, sum(x < 0 for x in d) / len(d)))
    return rows

# one figure, two axes sharing the row labels: against linear (left), against coordinates (right)
r1 = paired_rows("crossdomain", "linear")
r2 = paired_rows("crossdomain", "coordinates")
# the values the chapter quotes beside the figure: per task and speed class, the number of windows,
# the mean paired difference with its 95% bootstrap interval, and the share of windows in which
# crossdomain has the smaller error
for b, rows in (("linear", r1), ("coordinates", r2)):
    for task, lab, n, m, lo, hi, better in rows:
        print(f"crossdomain - {b:11s} {task:10s} {lab:12s} windows {n:5d} mean {m:7.1f} "
              f"[{lo:7.1f}, {hi:7.1f}] better {better:.3f}")
fig = plt.figure(figsize=(TW, 2.3))
axes = (fig.add_axes([0.345, 0.17, 0.27, 0.78]), fig.add_axes([0.70, 0.17, 0.21, 0.78]))
ys = [k + (0.6 if r[0] == "prediction" else 0) for k, r in enumerate(r1)]
for ax, rows, xlabel in ((axes[0], r1, r"\textsf{crossdomain} $-$ \textsf{linear} (m)"),
                         (axes[1], r2, r"\textsf{crossdomain} $-$ \textsf{coordinates} (m)")):
    for y, (task, lab, n, m, lo, hi, better) in zip(ys, rows):
        ax.plot([lo, hi], [y, y], color=INK, lw=0.9)
        ax.scatter([m], [y], s=12, color=ORANGE if lab == "all windows" else INK, zorder=3)
        ax.text(1.03, y, f"{100 * better:.0f}\\%", transform=ax.get_yaxis_transform(), va="center", color=MUTED)
    ax.text(1.03, -0.85, "better", transform=ax.get_yaxis_transform(), va="center", color=MUTED)
    ax.axvline(0, color=GRAY, lw=0.6, ls="--")
    ax.set_yticks(ys); ax.tick_params(axis="y", length=0)
    ax.set_ylim(max(ys) + 0.6, -1.2)
    ax.set_xlabel(xlabel)
    for sp in ("top", "right", "left"): ax.spines[sp].set_visible(False)
axes[0].set_yticklabels([f"{t.capitalize()}, {lab}" for t, lab, *_ in r1])
axes[1].set_yticklabels([])
save(fig, "errors_paired")
with open("paired_rows.txt", "w") as f:
    for r in r1 + r2: f.write(repr(r) + "\n")

# ---- median error against isolation and horizon, moving windows
def curve(fname, xmax, name, xlabel, legend):
    d = defaultdict(dict)
    for r in csv.DictReader(open(fname)):
        if r["class"] == "moving" and int(r["x"]) <= xmax:
            d[r["model"]][int(r["x"])] = (float(r["median"]), int(r["n"]))
    fig = plt.figure(figsize=(0.44 * TW, 2.1))
    ax = fig.add_axes([0.2, 0.2, 0.76, 0.76])
    for m in ("linear", "coordinates", "crossdomain"):
        xs = sorted(d[m]); ys = [d[m][x][0] for x in xs]
        ax.plot(xs, ys, lw=1, ms=3, label=m, **MODEL_STYLE[m])
    ax.set_yscale("log")
    ax.set_xticks(range(1, xmax + 1))
    ax.set_xlabel(xlabel); ax.set_ylabel("median error (m)")
    for s in ("top", "right"): ax.spines[s].set_visible(False)
    ax.grid(color="#e8e8e8", lw=0.4, which="major")
    if legend:
        ax.legend(handles=[Line2D([], [], lw=1, ms=3, label=r"\textsf{" + m + "}", **MODEL_STYLE[m])
                           for m in ("linear", "coordinates", "crossdomain")],
                  loc="lower right", frameon=True, fancybox=False, edgecolor=INK, framealpha=1).get_frame().set_linewidth(0.5)
    save(fig, name)
    return d

iso = curve("isolation_curve.csv", 8, "errors_isolation", "minutes to the nearest\nvisible position", True)
hor = curve("horizon_curve.csv", 3, "errors_horizon", "minutes after the last\nvisible position", False)
with open("curve_points.txt", "w") as f:
    for nm, d in (("iso", iso), ("hor", hor)):
        for m in d:
            f.write(f"{nm} {m} " + " ".join(f"{x}:{d[m][x][0]:.0f}/{d[m][x][1]}" for x in sorted(d[m])) + "\n")

# ---- the bound of 06_exact.sql (GapAreas) on the gap 5452
csv.field_size_limit(1 << 26)   # the WKT of a large protected area exceeds the default limit
g = list(csv.reader(open("q14_gap.csv")))[1]   # duplicate header names: read by position
ax_, ay_, bx_, by_, reach = (float(v) for v in g)
path = [r for r in csv.DictReader(open("q14_path.csv"))]
areas = [(r["nameeng"], wkt.loads(r["st_astext"])) for r in csv.DictReader(open("q14_areas.csv"))]
KIND = {"Sandbanker ud for Thyborøn": "entered", "Thisted Kommune public": "possible"}
cx, cy = (ax_ + bx_) / 2, (ay_ + by_) / 2
R = 1.25 * reach
view = box(cx - R, cy - R, cx + R, cy + R)
fig = plt.figure(figsize=(0.97 * TW, 0.78 * TW))
ax = fig.add_axes([0.01, 0.01, 0.98, 0.98])
km = lambda x, y: ((x - cx) / 1000, (y - cy) / 1000)
STY = {"excluded": dict(fc="#d9d9d9", ec=MUTED, hatch="////"), "possible": dict(fc="#cfe2f3", ec=BLUE),
       "entered": dict(fc="#fde0c5", ec=ORANGE)}
for name, geom in areas:
    kind = KIND.get(name, "excluded")
    clip = geom.intersection(view)
    polys = getattr(clip, "geoms", [clip])
    for p in polys:
        if p.is_empty or p.geom_type != "Polygon": continue
        xs, ys = zip(*[km(x, y) for x, y in p.exterior.coords])
        ax.fill(xs, ys, lw=0.5, zorder=1, **STY[kind])
for (px, py) in ((ax_, ay_), (bx_, by_)):
    ax.add_patch(Circle(km(px, py), reach / 1000, fill=False, ls=(0, (3, 2)), lw=0.6, ec=MUTED, zorder=2))
c = math.hypot(bx_ - ax_, by_ - ay_) / 2; a = reach / 2; b = math.sqrt(a * a - c * c)
ang = math.degrees(math.atan2(by_ - ay_, bx_ - ax_))
ax.add_patch(Ellipse(km(cx, cy), 2 * a / 1000, 2 * b / 1000, angle=ang, fill=False, lw=1.0, ec=INK, zorder=3))
obs = [km(float(r["st_x"]), float(r["st_y"])) for r in path if r["ingap"] == "f"]
rec = [km(float(r["st_x"]), float(r["st_y"])) for r in path if r["ingap"] == "t"]
ax.plot(*zip(*obs), ls="", marker="o", ms=1.6, color=BLUE, zorder=4)
ax.plot(*zip(*([km(ax_, ay_)] + rec + [km(bx_, by_)])), lw=0.8, color=ORANGE, marker="o", ms=1.8, zorder=5)
ax.plot(*zip(km(ax_, ay_), km(bx_, by_)), ls="", marker="D", ms=3.5, color=INK, zorder=6)
ax.annotate(r"$p_a$", km(ax_, ay_), xytext=(5, 4), textcoords="offset points")
ax.annotate(r"$p_b$", km(bx_, by_), xytext=(-13, -10), textcoords="offset points")
ax.set_xlim(-R / 1000, R / 1000); ax.set_ylim(-0.8 * R / 1000, 0.8 * R / 1000)
ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
for s in ax.spines.values(): s.set_linewidth(0.5)
ax.plot([R / 1000 - 6, R / 1000 - 1], [-0.8 * R / 1000 + 1.2] * 2, color=INK, lw=1)
ax.text(R / 1000 - 3.5, -0.8 * R / 1000 + 1.5, "5 km", ha="center", va="bottom")
leg = [Patch(fc="#d9d9d9", ec=MUTED, hatch="////", lw=0.5, label=r"excluded (\textsf{Possible} false)"),
       Patch(fc="#cfe2f3", ec=BLUE, lw=0.5, label=r"possible, not entered by the path"),
       Patch(fc="#fde0c5", ec=ORANGE, lw=0.5, label=r"possible, entered by the path"),
       Line2D([], [], color=INK, lw=1, label="reachable region (ellipse)"),
       Line2D([], [], color=MUTED, lw=0.6, ls=(0, (3, 2)), label=r"within reach of $p_a$ or $p_b$"),
       Line2D([], [], color=ORANGE, lw=0.8, marker="o", ms=1.8, label="reconstructed path"),
       Line2D([], [], color=BLUE, ls="", marker="o", ms=1.6, label="positions of the window")]
lg = ax.legend(handles=leg, loc="upper left", frameon=True, fancybox=False, edgecolor=INK, framealpha=1)
lg.get_frame().set_linewidth(0.5)
save(fig, "errors_q14_gap5452")
