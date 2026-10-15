#!/usr/bin/env python3
"""Draw the in-file-ordering figure of chapter 10 from a run of the MobilityLakehouse benchmark.

One file per in-file ordering (L0, L0X, L0Z, L0H), inorder_<layout>.<EXT> in the output directory:
the segments of one day as their bounding boxes' centroids, coloured by the row group holding them,
with each row group's own bounding box drawn over them: a tighter box is a box a query can skip on.
All four share one pair of limits, and none carries a title -- the book sets them as subfigures and
letters them, and each file's row-group count is printed when it is written.

  ./inorder_figures.py [DAY [OUTDIR]]

DAY is the day the panels are drawn from, 2026-01-15 by default.

Environment: RUN, the run directory under <data>/stage/planar/ of the MobilityLakehouse checkout,
holding L0/ and layouts_daily/ (40_order_layouts.sh writes the latter); ROOT, that <data>
directory, when RUN is not given (RUN is then ROOT/stage/planar); DUCKDB_ENGINE (duckdb), the
shell that reads the Parquet; OUTDIR defaults to figures/ under ROOT/results/planar, else to
figs/ beside this script. EXT (png), the format of the panels, pdf for the book; RASTER (1),
whether their segment markers are one embedded image, the boxes staying vectors; DPI (300), the
resolution of the PNG and of that image.
"""
import os
import subprocess
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.backends import backend_pdf

# The PDF backend's own `#_writeImg` stores an image of 256 colours or fewer as an indexed
# palette. The book keeps every embedded image full colour (DeviceRGB, Flate), so this wraps that
# routine and, while it writes an image, hides the colour count so that it takes its RGB branch.
_WRITE_IMG = backend_pdf.PdfFile._writeImg


def _write_img_rgb(self, data, id, smask=None):
    getcolors = backend_pdf.Image.Image.getcolors
    backend_pdf.Image.Image.getcolors = lambda img, maxcolors=256: None
    try:
        return _WRITE_IMG(self, data, id, smask)
    finally:
        backend_pdf.Image.Image.getcolors = getcolors


backend_pdf.PdfFile._writeImg = _write_img_rgb

# The grid colour of the figures of MobilityLakehouse's 74_figures.py, and a qualitative ramp for
# the row groups, which are a nominal scale: a sequential one would suggest an order between groups
# that pruning does not care about.
GRID = '#d8d7d2'
GROUP_COLORS = plt.get_cmap('tab20').colors
ORDERINGS = [('L0', 'L0 base (no sort)'), ('L0X', 'Lexicographic'),
             ('L0Z', 'Z-order (Morton)'), ('L0H', 'Hilbert')]


def duckdb(sql):
    """Run one statement and return its rows, the engine reporting its own errors."""
    engine = os.environ.get('DUCKDB_ENGINE', 'duckdb')
    out = subprocess.run([engine, '-csv', '-noheader', '-c', sql],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'inorder_figures.py: {engine} failed\n{out.stderr.strip()}')
    return [line.split(',') for line in out.stdout.splitlines() if line]


def layout_file(run, layout, day):
    """The one Parquet file of a layout for a day; L0 keeps the Hive partitioning, the rest do not."""
    if layout == 'L0':
        y, m, _ = day.split('-')
        return os.path.join(run, 'L0', f'year={y}', f'month={m}', f'day-{day}.parquet')
    return os.path.join(run, 'layouts_daily', layout, f'day-{day}.parquet')


def row_groups(path):
    """Each row group's first and last row index, from the row counts the footer states."""
    rows = duckdb(f"""SELECT row_group_id, any_value(row_group_num_rows) FROM
                      parquet_metadata('{path}') GROUP BY 1 ORDER BY 1""")
    spans, start = [], 0
    for _, num in rows:
        spans.append((start, start + int(num)))
        start += int(num)
    return spans


def segments(path):
    """Every segment's centroid in file order, which is the order the row groups cut."""
    rows = duckdb(f"""SELECT file_row_number, (trip_xmin + trip_xmax) / 2,
                             (trip_ymin + trip_ymax) / 2
                      FROM read_parquet('{path}', file_row_number = true)
                      ORDER BY file_row_number""")
    return [(float(r[1]), float(r[2])) for r in rows]


def inorder(run, day, outdir):
    """One FILE per ordering, the segments coloured by row group under each group's own box.

    One file per ordering rather than one grid of four, because the book sets them as LaTeX
    subfigures: the letter and the caption are then the document's, so they follow the numbering
    and the font of every other figure, and no text is baked into the image where a reader cannot
    select it and a reviewer cannot tell it from data. The panels carry no title for the same
    reason, and the row-group count each one holds is printed here so the caption can state it.

    Every panel is drawn on ONE pair of limits, taken over all four orderings. Four separate
    figures otherwise autoscale separately, and a reader comparing box sizes across them would be
    comparing four different scales -- the one thing a grid of four gave for free.
    """
    drawn = {}
    for layout, title in ORDERINGS:
        path = layout_file(run, layout, day)
        if not os.path.exists(path):
            sys.exit(f'inorder_figures.py: no {path}')
        drawn[layout] = (segments(path), row_groups(path), title)

    every = [p for pts, _, _ in drawn.values() for p in pts]
    xlim = (min(p[0] for p in every), max(p[0] for p in every))
    ylim = (min(p[1] for p in every), max(p[1] for p in every))
    pad = 0.02 * max(xlim[1] - xlim[0], ylim[1] - ylim[0])

    # The segments are the dense layer, some twelve thousand markers a panel: drawn as vectors
    # they are one marker call each and make the page slow to render. With RASTER=1 (the default)
    # every row group's markers sit below the axes' rasterization z-order, so the PDF holds them as
    # ONE lossless image at DPI (300), while the row-group boxes, the subject of the figure, are
    # drawn above them as vectors. RASTER=0 draws the markers as vectors too.
    raster = os.environ.get('RASTER', '1') == '1'
    dpi = int(os.environ.get('DPI', '300'))
    for layout, (pts, spans, title) in drawn.items():
        fig, ax = plt.subplots(figsize=(6, 4.5))
        if raster:
            ax.set_rasterization_zorder(1.5)
        for g, (lo, hi) in enumerate(spans):
            part = pts[lo:hi]
            if not part:
                continue
            color = GROUP_COLORS[g % len(GROUP_COLORS)]
            ax.scatter([p[0] for p in part], [p[1] for p in part], s=3.5, color=color,
                       linewidths=0, zorder=1)
            xs = [p[0] for p in part]
            ys = [p[1] for p in part]
            ax.add_patch(Rectangle((min(xs), min(ys)), max(xs) - min(xs), max(ys) - min(ys),
                                   fill=False, edgecolor=color, linewidth=1.4, zorder=2))
        ax.set_xlim(xlim[0] - pad, xlim[1] + pad)
        ax.set_ylim(ylim[0] - pad, ylim[1] + pad)
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_aspect('equal')
        for sp in ax.spines.values():
            sp.set_color(GRID)
        out = os.path.join(outdir, f"inorder_{layout}.{os.environ.get('EXT', 'png')}")
        fig.tight_layout()
        fig.savefig(out, dpi=dpi, facecolor='white')
        plt.close(fig)
        print(f'wrote {out}  (day {day}, {title}, {len(spans)} row '
              f'group{"" if len(spans) == 1 else "s"})')


def main():
    # An empty DAY is the default rather than an error, so a caller naming only the output
    # directory passes one positionally without having to repeat the day.
    day = (sys.argv[1] if len(sys.argv) > 1 else '') or os.environ.get('DAY') or '2026-01-15'
    root = os.environ.get('ROOT')
    run = os.environ.get('RUN') or (root and os.path.join(root, 'stage', 'planar'))
    if not run:
        sys.exit('inorder_figures.py: set RUN to a run of the MobilityLakehouse benchmark, or ROOT '
                 'to its data directory')
    outdir = sys.argv[2] if len(sys.argv) > 2 else (
        os.path.join(root, 'results', 'planar', 'figures') if root else
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'figs'))
    os.makedirs(outdir, exist_ok=True)
    inorder(run, day, outdir)


if __name__ == '__main__':
    main()
