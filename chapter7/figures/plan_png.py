"""Render a portion of a DuckDB EXPLAIN ANALYZE text tree as a PNG, black monospace on white,
like the plan figures of Chapter 7 (queryduckdbproc_a/b, queryprocplan8, mduckq14plan).


usage: plan_png.py <plan.txt> <out.png> <first-line-regex> <occurrence> <ncols-from> <ncols-to>
                   <nlines> [font-px]
The block starts at the box-top line just above the <occurrence>-th line matching the regex.
"""
import re
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
src, out, rx, occ, c0, c1, n = sys.argv[1:8]
px = int(sys.argv[8]) if len(sys.argv) > 8 else 26
lines = [l.rstrip('\n') for l in open(src, encoding='utf-8') if 'ICU' not in l]
hits = [i for i, l in enumerate(lines) if re.search(rx, l)]
start = hits[int(occ)] - 1
block = [l[int(c0):int(c1)].rstrip() for l in lines[start:start + int(n)]]
font = ImageFont.truetype(FONT, px)
cw = font.getbbox('M')[2]
lh = int(px * 1.25)
w = max(len(l) for l in block) * cw + 2 * cw
h = len(block) * lh + lh
img = Image.new('RGB', (w, h), 'white')
d = ImageDraw.Draw(img)
for i, l in enumerate(block):
    d.text((cw, lh // 2 + i * lh), l, font=font, fill='black')
img.save(out)
print(out, img.size)
print('\n'.join(block))
