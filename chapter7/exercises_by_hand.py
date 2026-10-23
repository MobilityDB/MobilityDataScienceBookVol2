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

"""The numbers of the answers of Exercise 7.4, worked by hand on the boxes of the
table TestGeo of the chapter, in the form of chapter11/exercises/by_hand.py: run
it to check them."""

# the box of row i is STBOX X((i,i),(i+0.5,i+0.5)), for i = 1, ..., 1000
boxes = [(i, i, i + 0.5, i + 0.5) for i in range(1, 1001)]

# (a): the boxes overlapping STBOX X((1000,1000),(1100,1100))
xmin, ymin, xmax, ymax = 1000, 1000, 1100, 1100
overlap = [b for b in boxes if b[0] <= xmax and b[2] >= xmin and b[1] <= ymax and b[3] >= ymin]
print("7.4 (a) rows", len(overlap), overlap)

# (b): the boxes strictly to the left of x = 500, whose largest x is below 500
print("7.4 (b) rows", sum(1 for b in boxes if b[2] < 500))

# (c): calls of a scalar LLM function over every report, and over the distinct names
print("7.4 (c) calls", 10_000_000, "and", 3_000, "ratio", round(10_000_000 / 3_000))
