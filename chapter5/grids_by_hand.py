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

"""The numbers of the answers of Exercise 5.3, worked by hand on the cells of the
position of longitude 10.60 and latitude 57.44 that grids_and_cells.sql computes:
run it to check them."""
import math

# (a) H3: a hexagon has seven children, a pentagon six, and 12 cells are pentagons
n = 122
for r in range(7):
    n = 7 * (n - 12) + 6 * 12
print("5.3 (a) cells of resolution 7", n, "=", 2 + 120 * 7 ** 7,
    "; descendants at resolution 9 of a hexagon of resolution 7", 7 ** 2)

# (b) QUADBIN: the parent halves the tile coordinates, the children double them
x, y, z = 4337, 2491, 13
print("5.3 (b) parent", (x // 2, y // 2, z - 1), "children",
    [(2 * x + i, 2 * y + j, z + 1) for j in (0, 1) for i in (0, 1)])

# (c) the area on the ground of a tile of resolution 13 at the equator and at latitude 57.44
side = 40075016.686 / 2 ** 13
lat = math.radians(57.44)
print("5.3 (c) km2 at the equator", round(side ** 2 / 1e6, 1), "cos2", round(math.cos(lat) ** 2, 3),
    "km2 at 57.44", round(side ** 2 * math.cos(lat) ** 2 / 1e6, 2))
