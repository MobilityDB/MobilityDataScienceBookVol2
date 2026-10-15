"""Print-size PDFs of the matplotlib figures of chapter 2 mpandas2-delhisplits (Fig. 2.4) and
mpandas2-generalization_{a,b,c} (Fig. 2.6): the trajectories and speeds the printed statements plot,
drawn at the width each figure is printed at, so that their text is set in the caption's font
(Latin Modern through the PGF backend) at the caption's size: pdflatex PGF, T1 + lmodern, 8 pt for
a dense figure, exact textwidth. #colorbar draws the shared speed colour bar."""
from pathlib import Path
from delhi_common import *  # noqa: F401,F403  (my_traj_split, mpd, ...)
import matplotlib
matplotlib.use("pgf")
import matplotlib.pyplot as plt
from matplotlib.cm import ScalarMappable
from matplotlib.colors import Normalize
from matplotlib.ticker import MaxNLocator, FormatStrFormatter

OUT = Path(__file__).resolve().parent / 'out'
OUT.mkdir(exist_ok=True)
PT = 1 / 72.27                     # inches per TeX point
TEXTWIDTH = 332.89723 * PT         # svmono \textwidth
FS = 8                             # caption size, half a point under for dense figures
matplotlib.rcParams.update({
    "pgf.texsystem": "pdflatex",
    "pgf.rcfonts": False,
    "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
    "font.family": "serif",
    "font.size": FS, "axes.labelsize": FS, "xtick.labelsize": FS, "ytick.labelsize": FS,
    "axes.linewidth": 0.4, "xtick.major.width": 0.4, "ytick.major.width": 0.4,
    "xtick.major.size": 2, "ytick.major.size": 2,
    "xtick.major.pad": 1.5, "ytick.major.pad": 1.5,
})
NORM = Normalize(vmin=0, vmax=20)  # the vmax of the printed statements; one scale for all panels
CMAP = "viridis"                   # the default colour map of Trajectory.plot


def style(ax, nx=3, ny=3):
    ax.set_xlabel(""); ax.set_ylabel("")
    ax.xaxis.set_major_locator(MaxNLocator(nx)); ax.yaxis.set_major_locator(MaxNLocator(ny))
    ax.xaxis.set_major_formatter(FormatStrFormatter("%.2f"))
    ax.yaxis.set_major_formatter(FormatStrFormatter("%.2f"))


def colorbar(fig, cax):
    cb = fig.colorbar(ScalarMappable(norm=NORM, cmap=CMAP), cax=cax, orientation="horizontal")
    cb.set_label("Speed (m/s)", labelpad=1)
    cb.outline.set_linewidth(0.4)
    cb.ax.tick_params(width=0.4, length=2)


for t in my_traj_split:
    print(t.id, "speed min %.3f max %.3f" % (t.df["speed"].min(), t.df["speed"].max())
          if "speed" in t.df else "no speed column")

# Fig. 2.4: the five portions in one row, one colour bar under them
fig = plt.figure(figsize=(TEXTWIDTH, 1.6), layout="constrained")
fig.get_layout_engine().set(w_pad=0.02, h_pad=0.02, wspace=0.02, hspace=0.02)
top, bottom = fig.subfigures(2, 1, height_ratios=[1, 0.42])
for ax, traj in zip(top.subplots(1, 5), my_traj_split):
    traj.plot(ax=ax, linewidth=1.0, capstyle="round", column="speed", norm=NORM, cmap=CMAP)
    # Five panels a fifth of the text wide cannot carry readable coordinates: frames only
    ax.set_xticks([]); ax.set_yticks([]); ax.set_xlabel(""); ax.set_ylabel("")
colorbar(fig, bottom.add_axes([0.25, 0.74, 0.5, 0.14]))
fig.savefig(f"{OUT}/mpandas2-delhisplits.pdf")
plt.close(fig)

# Fig. 2.6: three panels at 0.31 textwidth each, the most three \subfloat fit on a line with their
# spacing, and their shared colour bar. The panels carry frames only, as those of Fig. 2.4, so that
# each trajectory fills its panel and its gradient shows; cropped to the frame, a panel holds no
# text and is printed at the width it is drawn at.
original_traj = my_traj_split.trajectories[1]
dp_generalized = mpd.DouglasPeuckerGeneralizer(original_traj).generalize(tolerance=0.001)
tdtr_generalized = mpd.TopDownTimeRatioGeneralizer(original_traj).generalize(tolerance=0.001)
W = 0.31 * TEXTWIDTH
for name, traj in [("a", original_traj), ("b", dp_generalized), ("c", tdtr_generalized)]:
    print(name, len(traj.df))
    fig, ax = plt.subplots(figsize=(W, W))
    fig.subplots_adjust(left=0, right=1, bottom=0, top=1)
    traj.plot(ax=ax, linewidth=1.25, capstyle="round", column="speed", norm=NORM, cmap=CMAP)
    ax.set_xticks([]); ax.set_yticks([]); ax.set_xlabel(""); ax.set_ylabel("")
    fig.savefig(f"{OUT}/mpandas2-generalization_{name}.pdf", bbox_inches="tight", pad_inches=0.005)
    plt.close(fig)
fig = plt.figure(figsize=(0.6 * TEXTWIDTH, 0.42))
colorbar(fig, fig.add_axes([0.03, 0.62, 0.94, 0.3]))
fig.savefig(f"{OUT}/mpandas2-generalization_cbar.pdf")
plt.close(fig)
