"""Print-size PDF of the speed colour bar mpandas2-generalization_cbar that the three maps of
Fig. 2.4 (fig_delhi.py) share, set in the caption's font (Latin Modern through the PGF backend) at
the caption's size: pdflatex PGF, T1 + lmodern, 8 pt."""
from pathlib import Path
import matplotlib
matplotlib.use("pgf")
import matplotlib.pyplot as plt
from matplotlib.cm import ScalarMappable
from matplotlib.colors import Normalize

OUT = Path(__file__).resolve().parent / 'out'
OUT.mkdir(exist_ok=True)
PT = 1 / 72.27                     # inches per TeX point
TEXTWIDTH = 332.89723 * PT         # svmono \textwidth
FS = 8                             # caption size, half a point under
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
NORM = Normalize(vmin=0, vmax=15)  # the vmax of speed_map of fig_delhi.py; one scale for all panels
CMAP = "viridis"                   # the default colour map of explore() for a numeric column


def colorbar(fig, cax):
    cb = fig.colorbar(ScalarMappable(norm=NORM, cmap=CMAP), cax=cax, orientation="horizontal")
    cb.set_ticks(range(0, 16, 5))
    cb.set_label("Speed (m/s)", labelpad=1)
    cb.outline.set_linewidth(0.4)
    cb.ax.tick_params(width=0.4, length=2)


# The scale 0-15 m/s of the maps of Fig. 2.4, which explore() draws with vmin=0 and vmax=15
fig = plt.figure(figsize=(0.6 * TEXTWIDTH, 0.42))
colorbar(fig, fig.add_axes([0.03, 0.62, 0.94, 0.3]))
# Cropped to its drawn content, so that the page holds the descenders of the label
fig.savefig(f"{OUT}/mpandas2-generalization_cbar.pdf", bbox_inches="tight", pad_inches=0.005)
plt.close(fig)
