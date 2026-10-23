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

"""The numbers of the answers of Exercises 10.4 and 10.5, worked by hand, in the
form of chapter11/exercises/by_hand.py: run it to check them."""
import math


def morton(x, y, bits=3):
    """The Z-order code of the cell (x, y), easting bits in the even positions"""
    code = 0
    for i in range(bits):
        code |= ((x >> i) & 1) << (2 * i) | ((y >> i) & 1) << (2 * i + 1)
    return code


print("10.4 (a)", {c: morton(*c) for c in ((3, 5), (4, 5), (2, 5), (3, 4))})
groups = math.ceil(1_000_000 / 2048)
print("10.4 (b) row groups", groups, "footer values", groups * 6 * 2)
one, two, four = (40 / 50) ** 2, 2 * (40 / 50) * (10 / 50), (10 / 50) ** 2
print("10.4 (c) probabilities", round(one, 2), round(two, 2), round(four, 2),
    "expected cells", round(one + 2 * two + 4 * four, 2))
print("10.5 (b) daily files", 31 * 40, "sorted-compact files", 40)
