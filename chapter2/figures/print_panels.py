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
from dateutil.tz import gettz
from matplotlib.colors import to_hex
from matplotlib.lines import Line2D
from matplotlib.transforms import offset_copy
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


EMPHASIS_LW = 1.0                  # points: the lines of the emphasis colour stand out of the data
LEGEND_GAP = 2 + 1.5 + FS + 2      # points: tick length, label pad, label height and a white gap


def _style(ax, map_, lw, ms, frame=True, margin=0.03, emphasis=None, tz=None):
    """Sets the text of ax at FS in the font of the captions, thins the data lines to lw points
    and the markers to ms points, and for a map removes the coordinates; frame False draws no
    frame, margin is the fraction of the data range left free around it, the lines of the colour
    emphasis are drawn EMPHASIS_LW wide, and a time axis is labelled in the time zone tz."""
    for a in (ax.title, ax.xaxis.label, ax.yaxis.label):
        a.set_fontsize(FS)
    ax.tick_params(labelsize=FS, width=0.4, length=2, pad=1.5)
    for s in ax.spines.values():
        s.set_linewidth(0.4)
    for line in ax.get_lines():
        if emphasis and to_hex(line.get_color()) == to_hex(emphasis):
            line.set_linewidth(EMPHASIS_LW)
        elif line.get_linewidth() > lw:
            line.set_linewidth(lw)
        if ms is not None and line.get_markersize() > ms:
            line.set_markersize(ms)
    for c in ax.collections:
        if isinstance(c, LineCollection):
            c.set_linewidth(min(lw, max(c.get_linewidth(), default=lw)))
        elif isinstance(c, PathCollection) and ms is not None:
            c.set_sizes([ms ** 2])
    leg = ax.get_legend()
    if leg:
        for t in leg.get_texts():
            t.set_fontsize(FS)
        leg.get_frame().set_linewidth(0.4)
    ax.grid(False)
    # A margin around the data, so that a frame drawn at the extent of the data (an extent
    # aggregate) stays clear of the frame of the panel
    ax.margins(margin)
    ax.set_frame_on(frame)
    if not frame:
        # The box of a map without a frame is its data: the limits a plotter set are dropped
        ax.autoscale(True)
        # The lines at the edge of the data, the box of a map without a frame, are drawn whole
        for c in ax.get_lines() + list(ax.collections) + list(ax.patches):
            c.set_clip_on(False)
    ax.autoscale_view()
    if leg:
        # Under the axes, just under the labels of the ticks of a chart (LEGEND_GAP points), so that
        # the legends of two panels side by side are at one height whatever their boxes
        leg.set_loc('upper center')
        leg.set_bbox_to_anchor((0.5, 0), transform=offset_copy(
            ax.transAxes, ax.figure, y=-LEGEND_GAP, units='points'))
        leg.borderaxespad = 0
        leg.set_ncols(2)
        leg.set_frame_on(False)
    if map_:
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_xlabel(''); ax.set_ylabel('')
        ax.set_aspect('equal', adjustable='datalim')
    elif isinstance(ax.xaxis.get_major_formatter(), mdates.DateFormatter) or \
            isinstance(ax.xaxis.get_major_locator(), mdates.DateLocator):
        loc = mdates.AutoDateLocator(minticks=3, maxticks=5, tz=tz)
        ax.xaxis.set_major_locator(loc)
        # A day is labelled by its number, the first of a month too, and the axis carries no
        # offset line naming the month or the day ('2020-Jun'), which the caption and the text give
        ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(
            loc, tz=tz, formats=['%Y', '%b', '%-d', '%H:%M', '%H:%M', '%S.%f'],
            zero_formats=['', '%Y', '%-d', '%b-%-d', '%H:%M', '%H:%M'],
            offset_formats=[''] * 6))
        # An axis of several days starts at the midnight of the day of its first value, so that
        # this day is labelled too, and no day before it
        lo, hi = ax.get_xlim()
        if hi - lo >= 1.5:
            first = mdates.num2date(ax.dataLim.x0, tz=gettz(tz) if tz else None)
            ax.set_xlim(mdates.date2num(first.replace(hour=0, minute=0, second=0, microsecond=0)), hi)
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


def print_panel(fig, ax, path, width, height, map_=False, lw=0.5, ms=2, frame=True, margin=0.03,
                emphasis=None, tz=None):
    """Saves ax alone as a page of width x height inches at path (PDF through PGF)."""
    others = [(a, a.get_visible()) for a in fig.axes if a is not ax]
    texts = [(t, t.get_visible()) for t in fig.texts]
    for a, _ in others:
        a.set_visible(False)
    for t, _ in texts:
        t.set_visible(False)
    _style(ax, map_, lw, ms, frame, margin, emphasis, tz)
    _fit(fig, [(ax, (0, 0, width, height))], width, height)
    fig.savefig(path, backend='pgf')
    for a, v in others:
        a.set_visible(v)
    for t, v in texts:
        t.set_visible(v)


def print_aligned(fig, panels):
    """Saves each (ax, path, width, height, style) of panels alone as a page of width x height inches,
    styled by the keyword arguments style of #_style as #print_panel styles it, the axes of every
    panel in one box: the one that clears the text of all of them, so that the boxes of the panels
    have the same size and the same place on their pages, and two panels set side by side are
    aligned at the top. The pages of the panels have one size."""
    width, height = panels[0][2], panels[0][3]
    if any((w, h) != (width, height) for _, _, w, h, _ in panels):
        raise ValueError('the panels of print_aligned have pages of different sizes')
    shown = [(a, a.get_visible()) for a in fig.axes] + [(t, t.get_visible()) for t in fig.texts]
    for t in fig.texts:
        t.set_visible(False)
    boxes = []
    for ax, _, _, _, style in panels:
        for a in fig.axes:
            a.set_visible(a is ax)
        _style(ax, **style)
        _fit(fig, [(ax, (0, 0, width, height))], width, height)
        boxes.append(ax.get_position())
    box = [max(b.x0 for b in boxes), max(b.y0 for b in boxes)]
    box += [min(b.x1 for b in boxes) - box[0], min(b.y1 for b in boxes) - box[1]]
    # A map without a frame has the shape of its data (its extent rectangle or its grid of tiles is
    # its box): the box of every panel is the one the map takes at the top of the common box
    for ax, _, _, _, style in panels:
        if style.get('map_') and not style.get('frame', True):
            ax.set_aspect('equal', adjustable='box', anchor='N')
            # the limits again those of the data, which the aspect of #_style widened to fill a box
            ax.autoscale_view()
            ax.set_position(box)
            ax.apply_aspect()
            box = list(ax.get_position(original=False).bounds)
    for ax, path, _, _, _ in panels:
        for a in fig.axes:
            a.set_visible(a is ax)
        ax.set_position(box)
        fig.savefig(path, backend='pgf')
    for a, v in shown:
        a.set_visible(v)


def print_panel_box(fig, ax, path, width, box_h, map_=False, lw=0.5, ms=2, tz=None):
    """Saves ax alone as a page width inches wide whose axes box is box_h inches high, the page as
    high as the box and the text above and under it, which #print_panel would fit inside a page of
    that height; returns the margins under and above the box, in inches, so that a panel beside it
    (a map printed by #print_map of vgprint.py) can be padded to the same page and the two boxes set
    side by side at the same height."""
    others = [(a, a.get_visible()) for a in fig.axes if a is not ax]
    texts = [(t, t.get_visible()) for t in fig.texts]
    for a, _ in others:
        a.set_visible(False)
    for t, _ in texts:
        t.set_visible(False)
    _style(ax, map_, lw, ms, tz=tz)
    _fit(fig, [(ax, (0, 0, width, box_h))], width, box_h)
    pos = ax.get_position()
    under, above = pos.y0 * box_h, (1 - pos.y1) * box_h
    height = box_h + under + above
    fig.set_size_inches(width, height)
    ax.set_position([pos.x0, under / height, pos.width, box_h / height])
    fig.savefig(path, backend='pgf')
    for a, v in others:
        a.set_visible(v)
    for t, v in texts:
        t.set_visible(v)
    return under, above


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
