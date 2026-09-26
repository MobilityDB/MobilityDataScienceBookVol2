"""Lay out the figure of the three cell grids of the MobilityDB manual
(doc/images/cellindex.png: one column per grid, the whole track in the upper row
and the excerpt one resolution finer in the lower row) as the figure of the
chapter: one row per grid, the whole track on the left and the excerpt on the
right.

    python3 cellgrids.py <cellindex.png> <cellgrids.png>

The manual image is fetched from the MobilityDB repository at the commit that
added it, for instance with
    curl -fLO https://raw.githubusercontent.com/MobilityDB/MobilityDB/688ef3e12bcff88de44c42ca6e71a554c1800c60/doc/images/cellindex.png
"""
import sys

from PIL import Image

COLS = (0, 746, 1492)     # left edge of the column of each grid in the manual
ROWS = (0, 441)           # top edge of the upper and lower rows in the manual
WIDTH = 700               # width of a panel
DX, DY = 740, 442         # placement of the panels in the figure

src = Image.open(sys.argv[1]).convert("RGB")
out = Image.new("RGB", (DX + WIDTH, 2 * DY + src.height - ROWS[1] + 3), "white")
for grid, x in enumerate(COLS):
    for row, y in enumerate(ROWS):
        bottom = ROWS[row + 1] if row + 1 < len(ROWS) else src.height
        out.paste(src.crop((x, y, x + WIDTH, bottom)), (DX * row, DY * grid))
out.save(sys.argv[2])
print("wrote", sys.argv[2], out.size)
