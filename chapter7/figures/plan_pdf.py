"""Render a portion of a DuckDB EXPLAIN ANALYZE text tree as a vector PDF, black monospace on white,
like the plan figures of Chapter 7 (queryduckdbproc_a/b, queryprocplan8, mduckq14plan).

The vector twin of `#plan_png.py` beside it: the same arguments select the same block, and the page
has the PNG's layout at 300 dpi (one PNG pixel is 1/300 inch), so the PDF is the PNG drawn as text,
with DejaVu Sans Mono embedded as a TrueType font.

usage: plan_pdf.py <plan.txt> <out.pdf> <first-line-regex> <occurrence> <ncols-from> <ncols-to>
                   <nlines> [font-px]
The block starts at the box-top line just above the <occurrence>-th line matching the regex.
"""
import re
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from PIL import ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
DPI = 300
src, out, rx, occ, c0, c1, n = sys.argv[1:8]
px = int(sys.argv[8]) if len(sys.argv) > 8 else 26
lines = [l.rstrip('\n') for l in open(src, encoding='utf-8') if 'ICU' not in l]
hits = [i for i, l in enumerate(lines) if re.search(rx, l)]
start = hits[int(occ)] - 1
block = [l[int(c0):int(c1)].rstrip() for l in lines[start:start + int(n)]]
# The layout of plan_png.py, in its pixels: the advance of 'M', a line height of 1.25 font px, a margin
# of one character, and each line drawn with its ascender line at lh/2 + i*lh
pil = ImageFont.truetype(FONT, px)
cw = pil.getbbox('M')[2]
lh = int(px * 1.25)
ascent = pil.getmetrics()[0]
w = max(len(l) for l in block) * cw + 2 * cw
h = len(block) * lh + lh

plt.rcParams['pdf.fonttype'] = 42
fig = plt.figure(figsize=(w / DPI, h / DPI), dpi=DPI)
fig.patch.set_facecolor('white')
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, w); ax.set_ylim(h, 0); ax.axis('off')
fp = FontProperties(fname=FONT, size=px * 72 / DPI)
for i, l in enumerate(block):
    ax.text(cw, lh // 2 + i * lh + ascent, l, fontproperties=fp, color='black', ha='left',
            va='baseline')
fig.savefig(out, dpi=DPI, facecolor='white')
print(out, (w, h))
print('\n'.join(block))
