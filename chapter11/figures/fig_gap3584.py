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

"""Draw the figure of the gap 3584 (MMSI 219281000, January 20, 2026) of the use case of chapter 11
at the printed size of the book (\\textwidth = 4.65 in), with the text in the face of the captions
(LM Roman, through the PGF backend and pdflatex): what each task gives the model, masks, reconstructs
or predicts, and ignores, with the AIS reports, the one-minute samples, and the reconstructions of the
models of the use case.

    psql -d ais -f export_gap3584.sql    # writes tp.csv, obs.csv, rec.csv, masks.csv
    python3 fig_gap3584.py

The CSV files are read from the working directory, where the figure is written as three PDF files,
the panels (a) and (b) and their shared legend, which the chapter sets as \\subfloat panels:
gap3584_tasks_a_v2.pdf, gap3584_tasks_b.pdf, and gap3584_tasks_legend.pdf. FS is the size of the
text in points (8 by default, half a point under the 8.5 pt of the captions)."""
import csv, math, os, statistics
from datetime import datetime
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

plt.rcParams.update({"pgf.texsystem": "pdflatex", "pgf.rcfonts": False, "font.family": "serif",
                     "font.size": float(os.environ.get("FS", "8")), "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}\usepackage{xcolor}",
                     "axes.linewidth": 0.6, "xtick.major.width": 0.6, "ytick.major.width": 0.6,
                     "xtick.major.size": 2.5, "ytick.major.size": 2.5})
BLUE, RED, PURPLE, ORANGE, LORANGE, GRAY, INK, MUTED = (
    "#1f77b4", "#d62728", "#7b2d8e", "#e8820c", "#f0c08a", "#9a9a9a", "#222222", "#555555")
MODEL = "crossdomain"
FS = float(os.environ.get("FS", "8"))  # half a point under \captionstyle = \small = 8.5 pt; PGF writes it as \fontsize{FS}
S, SB, LW = 16, 14, 1.1     # marker area (pt^2) of a sample and of a bounding report, ring width

def ts(s): return datetime.fromisoformat(s.replace("+01", "+01:00"))
T0 = ts("2026-01-20 06:46:00+01")
def mins(t): return (t - T0).total_seconds() / 60

tp = {int(r["pointidx"]): r for r in csv.DictReader(open("tp.csv"))}
for r in tp.values():
    r["m"] = mins(ts(r["t"])); r["gap"] = r["ingap"] == "t"; r["bnd"] = r["bound"] == "t"
    r["xy"] = (float(r["x"]), float(r["y"])) if r["x"] else None
obs = [(mins(ts(r["t"])), float(r["x"]), float(r["y"])) for r in csv.DictReader(open("obs.csv"))]
masks = {}
for r in csv.DictReader(open("masks.csv")): masks.setdefault(r["task"], set()).add(int(r["pointidx"]))
rec = {(r["model"], r["task"], int(r["pointidx"])): (float(r["x"]), float(r["y"]))
       for r in csv.DictReader(open("rec.csv"))}

def err(model, task, i):
    a, b = rec[(model, task, i)], tp[i]["xy"]
    return math.hypot(a[0] - b[0], a[1] - b[1])
def med(model, task, idx): return statistics.median(err(model, task, i) for i in idx)

N = len(tp)
gs, ge = tp[15]["m"], tp[28]["m"]
assert not any(gs < o[0] < ge for o in obs), "a report inside the gap: check the time zone of obs.csv"
rec_before = sorted(i for i in masks["recovery"] if i <= 15)
rec_after = sorted(i for i in masks["recovery"] if i >= 28)
pred = sorted(masks["prediction"])

W, H = 332.89723 / 72.27, 6.4   # \textwidth, so the figure is printed unscaled
fig = plt.figure(figsize=(W, H))
ax = fig.add_axes([0.01, 0.405, 0.98, 0.585])
ax.set_xlim(-0.6, 41.6); ax.set_ylim(-0.7, 7.75); ax.invert_yaxis(); ax.axis("off")

def row_title(y, title, sub):
    # one line, one baseline: the bold title, then the description in the muted ink
    ax.text(-0.4, y - 0.33, rf"\textbf{{{title}}}\enspace{{\color[HTML]{{{MUTED[1:]}}}{sub}}}",
            ha="left", va="baseline", fontsize=FS, color=INK)
def brace(y, a, b, color, text, dy=0.07):
    a, b = (tp[v]["m"] if isinstance(v, int) else v for v in (a, b))
    ax.plot([a, a, b, b], [y - 0.06, y, y, y - 0.06], color=color, lw=0.7)
    ax.text((a + b) / 2, y + dy, text, ha="center", va="top", fontsize=FS, color=color, linespacing=1.05)
def dot(y, i, kind):
    m, b = tp[i]["m"], tp[i]["bnd"]
    mk, s = ("D", SB) if b else ("o", S)
    if kind == "ctx":    ax.scatter(m, y, s=s, marker=mk, color=BLUE, lw=0, zorder=3)
    elif kind == "na":   ax.scatter(m, y, s=s, marker=mk, facecolor="white", edgecolor=GRAY, ls=":", lw=0.8, zorder=3)
    elif kind == "none": ax.scatter(m, y, s=7, marker="x", color=GRAY, lw=0.7, zorder=3)
    else:
        c = {"rec": RED, "pred": PURPLE, "gap": ORANGE, "gapns": LORANGE}[kind]
        ax.scatter(m, y, s=s, marker=mk, facecolor="white", edgecolor=c, lw=LW, zorder=3)

# AIS reports
y = 0.15
for m, _, _ in obs: ax.plot([m, m], [y - 0.13, y + 0.13], color=MUTED, lw=0.15, zorder=2)
row_title(y, "AIS reports", "positions transmitted by the vessel")
nb = sum(1 for o in obs if o[0] <= gs)
brace(y + 0.25, obs[0][0], float(gs), INK, f"{nb} reports, one every\n{60 * (gs - obs[0][0]) / (nb - 1):.0f} s on average")
brace(y + 0.25, gs + 0.2, ge - 0.2, MUTED, "none for 11 min 48 s,\n6.85 km travelled")
brace(y + 0.25, ge, obs[-1][0], INK, f"{len(obs) - nb} reports")

# TripPoints
y = 1.7
for i in range(N): dot(y, i, "na" if tp[i]["gap"] else "ctx")
row_title(y, "TripPoints", "model input; 15 and 28 are the reports bounding the gap")
brace(y + 0.22, 0, 15, BLUE, "one position per minute,\ninterpolated between reports")
brace(y + 0.22, tp[16]["m"], tp[27]["m"], MUTED, "no position\n(InGap)")
brace(y + 0.22, 28, 43, BLUE, "one position per minute,\ninterpolated between reports")

# recovery
y = 3.25
for i in range(N): dot(y, i, "gapns" if tp[i]["gap"] else ("rec" if i in masks["recovery"] else "ctx"))
row_title(y, "Recovery", "about half of the recorded positions masked")
brace(y + 0.22, 0, 15, RED, f"{len(rec_before)} of 16 masked")
brace(y + 0.22, tp[16]["m"], tp[27]["m"], ORANGE, "reconstructed,\nnot scored")
brace(y + 0.22, 28, 43, RED, f"{len(rec_after)} of 16 masked")

# prediction
y = 4.8
for i in range(N): dot(y, i, "none" if tp[i]["m"] > gs else ("pred" if i in pred else "ctx"))
row_title(y, "Prediction", "last 3 positions before the gap masked, later positions withheld")
brace(y + 0.22, 0, 12, BLUE, "visible context")
brace(y + 0.22, 13, 15, PURPLE, "predicted")
brace(y + 0.22, tp[16]["m"], 43, GRAY, "not given to the model")

# gap
y = 6.35
for i in range(N): dot(y, i, "gap" if tp[i]["gap"] else "ctx")
row_title(y, "Gap", "positions inside the gap masked")
brace(y + 0.22, 0, 15, BLUE, "visible context")
brace(y + 0.22, tp[16]["m"], tp[27]["m"], ORANGE, "reconstructed,\ntruth unknown")
brace(y + 0.22, 28, 43, BLUE, "visible context")

# time axis
yb = 7.15
ax.plot([-0.4, 41.4], [yb, yb], color=INK, lw=0.6)
for i in range(N): ax.plot([tp[i]["m"]] * 2, [yb, yb + 0.05], color=INK, lw=0.4)
for i in (0, 15, 28, 43):
    m = tp[i]["m"]
    ax.plot([m, m], [yb, yb + 0.1], color=INK, lw=0.6)
    t = ts(tp[i]["t"]).strftime("%H:%M:%S" if i in (15, 28) else "%H:%M")
    ax.text(m, yb + 0.14, f"{t} ({i})", ha="center" if 0 < i < 43 else ("left" if i == 0 else "right"),
            va="top", fontsize=FS, color=INK)

# map: true positions, rotated so that the course from report 15 to report 28 runs left to right
mx = fig.add_axes([0.115, 0.215, 0.875, 0.16])
ox, oy = tp[15]["xy"]
ex, ey = tp[28]["xy"][0] - ox, tp[28]["xy"][1] - oy
L = math.hypot(ex, ey); ux, uy = ex / L, ey / L
def km(p):
    dx, dy = p[0] - ox, p[1] - oy
    return ((dx * ux + dy * uy) / 1000, -dx * uy + dy * ux)
lo, hi = 8, 35
pts = [km((o[1], o[2])) for o in obs if tp[lo]["m"] - 0.3 <= o[0] <= tp[hi]["m"] + 0.3]
mx.scatter(*zip(*pts), s=0.6, color=INK, lw=0, zorder=2)
a, b = km(tp[15]["xy"]), km(tp[28]["xy"])
mx.plot([a[0], b[0]], [a[1], b[1]], color=GRAY, ls="--", lw=0.7, zorder=1)
for i in range(lo, hi + 1):
    if tp[i]["gap"]: continue
    mx.scatter(*km(tp[i]["xy"]), s=SB if tp[i]["bnd"] else S, marker="D" if tp[i]["bnd"] else "o",
               facecolor="none", edgecolor=BLUE, lw=0.9, zorder=3)
for i in range(16, 28):
    mx.scatter(*km(rec[(MODEL, "gap", i)]), s=S, facecolor="white", edgecolor=ORANGE, lw=LW, zorder=4)
    mx.scatter(*km(rec[("linear", "gap", i)]), s=12, marker="+", color=MUTED, lw=0.7, zorder=5)
for task, c in (("recovery", RED), ("prediction", PURPLE)):
    for i in sorted(masks[task]):
        if lo <= i <= hi:
            p, t = km(rec[(MODEL, task, i)]), km(tp[i]["xy"])
            mx.plot([t[0], p[0]], [t[1], p[1]], color=c, lw=0.6, zorder=3)
            mx.scatter(*p, s=S * 0.8, facecolor="white", edgecolor=c, lw=LW, zorder=4)
for i in (8, 15, 16, 27, 28, 35):
    p = km(rec[(MODEL, "gap", i)]) if tp[i]["gap"] else km(tp[i]["xy"])
    mx.annotate(str(i), p, xytext=(0, 4), textcoords="offset points", ha="center", va="bottom",
                fontsize=FS, color=INK)
mx.axhline(0, color="#d0d0d0", lw=0.5, zorder=0)
mx.set_xlabel("km along the course from report 15 to report 28", fontsize=FS, labelpad=2)
for sp in ("top", "right"): mx.spines[sp].set_visible(False)
mx.tick_params(labelsize=FS)
mx.set_ylim(-230, 330); mx.set_yticks([-200, 0, 200])
mx.grid(color="#e8e8e8", lw=0.4); mx.set_axisbelow(True)
bb = mx.get_position()
kx = (mx.get_xlim()[1] - mx.get_xlim()[0]) * 1000 / (bb.width * W)
ky = (mx.get_ylim()[1] - mx.get_ylim()[0]) / (bb.height * H)
STRETCH = round(kx / ky)
mx.set_ylabel(rf"m across ($\times${STRETCH})", fontsize=FS, labelpad=1)
print("stretch", STRETCH)

leg = [
    Line2D([], [], ls="", marker="|", ms=5, mew=0.6, color=INK, label="AIS report"),
    Line2D([], [], ls="", marker="o", ms=4, color=BLUE, mew=0, label="sample, visible"),
    Line2D([], [], ls="", marker="D", ms=3.5, color=BLUE, mew=0, label="report bounding the gap"),
    Line2D([], [], ls="", marker="o", ms=4, mfc="white", mec=RED, mew=LW, label="masked, reconstructed"),
    Line2D([], [], ls="", marker="o", ms=4, mfc="white", mec=PURPLE, mew=LW, label="masked, predicted"),
    Line2D([], [], ls="", marker="o", ms=4, mfc="white", mec=ORANGE, mew=LW, label="in the gap, reconstructed"),
    Line2D([], [], ls="", marker="o", ms=4, mfc="white", mec=LORANGE, mew=LW, label="in the gap, not scored"),
    Line2D([], [], ls="", marker="x", ms=3, mew=0.7, color=GRAY, label="not given to the model"),
    Line2D([], [], ls="", marker="+", ms=4, mew=0.7, color=MUTED, label="linear, in the gap"),
    Line2D([], [], ls="--", lw=0.7, color=GRAY, label="from report 15 to report 28"),
]
lg = fig.legend(handles=leg, loc="lower center", bbox_to_anchor=(0.5, 0.017), ncol=2, frameon=True,
                fancybox=False, edgecolor=INK, borderpad=0.6, fontsize=FS, handletextpad=0.4,
                labelspacing=0.3, columnspacing=1.5, handlelength=1.6)
lg.get_frame().set_linewidth(0.5)
# one file per panel and one for the shared legend, set as \subfloat panels by the chapter
from matplotlib.transforms import Bbox
for name, (y0, y1) in (("a_v2", (0.40, 0.972)), ("b", (0.161, 0.385)), ("legend", (0.022, 0.157))):
    fig.savefig(f"gap3584_tasks_{name}.pdf", backend="pgf", bbox_inches=Bbox([[0, y0 * H], [W, y1 * H]]))
