"""Print step of the matplotlib figures of the PyMEOS section of chapter 2. The listings draw on
figures of 20 x 10 inches; #print_panel lays one of their axes out again on a page of the size at
which the book prints it, so that the text is set in the caption's font at the caption's size,
as #style of fig_charts_print.py does for the MovingPandas figures: Latin Modern through the PGF
backend, 8 pt, the size the dense figures of the book take. A map keeps its frame and loses its
coordinates; a chart keeps its axes. The lines of the data are drawn at a width that reads at
print size. #print_grid does the same for a grid of maps with titles, which it wraps at the
width of a panel."""
import matplotlib
import matplotlib.dates as mdates
from matplotlib.lines import Line2D
from matplotlib.collections import LineCollection, PathCollection

PT = 1 / 72.27                     # inches per TeX point
CM = 1 / 2.54                      # inches per centimeter
TEXTWIDTH = 332.89723 * PT         # svmono \textwidth
FS = 8                             # caption size, half a point under for dense figures
matplotlib.rcParams.update({
    "pgf.texsystem": "pdflatex",
    "pgf.rcfonts": False,
    "pgf.preamble": r"\usepackage[T1]{fontenc}\usepackage{lmodern}",
    "font.family": "serif",
})
PAD = 1.5 * PT                     # white space around the drawn content


def _texts(ax):
    yield ax.title
    yield ax.xaxis.label
    yield ax.yaxis.label
    yield ax.xaxis.get_offset_text()
    yield ax.yaxis.get_offset_text()
    yield from ax.get_xticklabels()
    yield from ax.get_yticklabels()
    leg = ax.get_legend()
    if leg:
        yield from leg.get_texts()


def _style(ax, map_, lw, ms):
    """Sets the text of ax at FS in the font of the captions, thins the data lines to lw points
    and the markers to ms points, and for a map removes the coordinates."""
    for a in (ax.title, ax.xaxis.label, ax.yaxis.label):
        a.set_fontsize(FS)
    ax.tick_params(labelsize=FS, width=0.4, length=2, pad=1.5)
    for s in ax.spines.values():
        s.set_linewidth(0.4)
    for line in ax.get_lines():
        if line.get_linewidth() > lw:
            line.set_linewidth(lw)
        if line.get_markersize() > ms:
            line.set_markersize(ms)
    for c in ax.collections:
        if isinstance(c, LineCollection):
            c.set_linewidth(min(lw, max(c.get_linewidth(), default=lw)))
        elif isinstance(c, PathCollection):
            c.set_sizes([ms ** 2])
    leg = ax.get_legend()
    if leg:
        for t in leg.get_texts():
            t.set_fontsize(FS)
        leg.get_frame().set_linewidth(0.4)
    ax.grid(False)
    # A margin around the data, so that a frame drawn at the extent of the data (an extent
    # aggregate) stays clear of the frame of the panel
    ax.margins(0.03)
    ax.autoscale_view()
    if leg and not map_:
        # Under the axes, clear of the data
        leg.set_loc('upper center')
        leg.set_bbox_to_anchor((0.5, -0.17), transform=ax.transAxes)
        leg.set_ncols(2)
        leg.set_frame_on(False)
    if map_:
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_xlabel(''); ax.set_ylabel('')
        ax.set_aspect('equal', adjustable='datalim')
    elif isinstance(ax.xaxis.get_major_formatter(), mdates.DateFormatter) or \
            isinstance(ax.xaxis.get_major_locator(), mdates.DateLocator):
        loc = mdates.AutoDateLocator(minticks=3, maxticks=5)
        ax.xaxis.set_major_locator(loc)
        ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(loc))
        for t in ax.get_xticklabels():
            t.set_rotation(0); t.set_ha('center')
    for t in _texts(ax):
        t.set_fontsize(FS)
        t.set_fontfamily('serif')


def _fit(fig, axes_boxes, width, height):
    """Places each axes in its box (left, bottom, right, top, in inches of a page width x height)
    shrunk by the text that sticks out of it, twice, since the ticks follow the size."""
    fig.set_size_inches(width, height)
    for ax, box in axes_boxes:
        ax.set_position([box[0] / width, box[1] / height, (box[2] - box[0]) / width,
                         (box[3] - box[1]) / height])
    for _ in range(3):
        fig.canvas.draw()
        r = fig.canvas.get_renderer()
        for ax, box in axes_boxes:
            tb = ax.get_tightbbox(r).transformed(fig.dpi_scale_trans.inverted())
            pos = ax.get_position().transformed(fig.transFigure).transformed(
                fig.dpi_scale_trans.inverted())
            l = box[0] + PAD + (pos.x0 - tb.x0)
            b = box[1] + PAD + (pos.y0 - tb.y0)
            rr = box[2] - PAD - (tb.x1 - pos.x1)
            t = box[3] - PAD - (tb.y1 - pos.y1)
            ax.set_position([l / width, b / height, (rr - l) / width, (t - b) / height])


def print_panel(fig, ax, path, width, height, map_=False, lw=0.5, ms=2):
    """Saves ax alone as a page of width x height inches at path (PDF through PGF)."""
    others = [(a, a.get_visible()) for a in fig.axes if a is not ax]
    texts = [(t, t.get_visible()) for t in fig.texts]
    for a, _ in others:
        a.set_visible(False)
    for t, _ in texts:
        t.set_visible(False)
    _style(ax, map_, lw, ms)
    _fit(fig, [(ax, (0, 0, width, height))], width, height)
    fig.savefig(path, backend='pgf')
    for a, v in others:
        a.set_visible(v)
    for t, v in texts:
        t.set_visible(v)


def wrap(fig, text, width):
    """Breaks text into lines no wider than width inches at FS: the French and the Dutch name of
    a name of several words broken between them, and after its hyphens ('Berchem-Sainte-Agathe')."""
    r = fig.canvas.get_renderer()
    tokens = []
    for i, part in enumerate(text.split(' - ')):
        pieces = part.split('-')
        tokens += [(p + '-' if j < len(pieces) - 1 else p, j == 0 and i > 0)
                   for j, p in enumerate(pieces)]
    probe = fig.text(0, 0, '', fontsize=FS)

    def w(s):
        probe.set_text(s)
        return probe.get_window_extent(r).width / fig.dpi

    lines, cur = [], ''
    for tok, starts_part in tokens:
        cand = tok if not cur else (cur + (' - ' if starts_part else '') + tok)
        if cur and (starts_part or w(cand) > width):
            lines.append(cur)
            cur = tok
        else:
            cur = cand
    lines.append(cur)
    probe.remove()
    return '\n'.join(lines)


def print_grid(fig, axes, path, ncols, width, cell_h, lw=0.4, gap=4 * PT):
    """Saves the maps axes as a grid of ncols columns on a page of the given width, each cell
    cell_h inches high under the titles of its row, wrapped at the width of a cell; each map is
    styled as #print_panel styles one."""
    shown = set(axes)
    for a in fig.axes:
        if a not in shown:
            a.set_visible(False)
    nrows = (len(axes) + ncols - 1) // ncols
    cw = (width - gap * (ncols - 1)) / ncols
    for ax in axes:
        _style(ax, True, lw, 2)
        ax.set_title(wrap(fig, ax.get_title(), cw - 2 * PAD), fontsize=FS, pad=2,
                     linespacing=1.0)
    # The title band of a row holds its longest title
    line = 1.2 * FS * PT
    title_h = [max(ax.get_title().count('\n') + 1 for ax in axes[r * ncols:(r + 1) * ncols])
               * line + 3 * PT for r in range(nrows)]
    height = nrows * cell_h + sum(title_h) + (nrows - 1) * gap
    fig.set_size_inches(width, height)
    top = height
    for r in range(nrows):
        y0 = top - title_h[r] - cell_h
        for c, ax in enumerate(axes[r * ncols:(r + 1) * ncols]):
            x0 = c * (cw + gap)
            ax.set_position([(x0 + PAD) / width, (y0 + PAD) / height, (cw - 2 * PAD) / width,
                             (cell_h - 2 * PAD) / height])
        top = y0 - gap
    fig.savefig(path, backend='pgf')
