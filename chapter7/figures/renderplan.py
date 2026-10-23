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

"""Draw a portion of a DuckDB plan, as printed by EXPLAIN or EXPLAIN ANALYZE, into a PDF figure.

Usage: renderplan.py <plan.txt> <first_line> <last_line> <first_col> <last_col> <out.pdf>
Lines and columns are 1-based and inclusive, over the plan text as the DuckDB shell prints it
(its box-drawing characters included). The figure is the text in DejaVu Sans Mono, drawn by
matplotlib with a tight bounding box, as the plan figures of chapter 7 are. The font is embedded
as TrueType: as a Type 3 font, the box-drawing characters of the last line, the bottom border of
the last operator, are not drawn.
"""
import sys

import matplotlib

matplotlib.use('pdf')
matplotlib.rcParams['pdf.fonttype'] = 42
import matplotlib.pyplot as plt  # noqa: E402

path, l0, l1, c0, c1, out = sys.argv[1], *map(int, sys.argv[2:6]), sys.argv[6]
lines = open(path, encoding='utf-8').read().splitlines()[l0 - 1:l1]
text = '\n'.join(l[c0 - 1:c1].rstrip() for l in lines)
fig = plt.figure(figsize=(0.075 * (c1 - c0 + 1), 0.16 * len(lines)))
fig.text(0, 1, text, family='DejaVu Sans Mono', size=8, va='top', ha='left', linespacing=0.98)
fig.savefig(out, bbox_inches='tight', pad_inches=0.02)
print(f"{out}: {len(lines)} lines, columns {c0}-{c1}")
