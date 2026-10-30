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

"""Write the rows of the Flock result tables of chapter 7 from the files of results/.

The rows are those of the tables tab:example1res to tab:example5res of chapter 7,
one table after the other, each preceded by a comment naming it. A text longer
than its column holds is cut and ends with \\dots, at the width of its table; a
Vietnamese letter absent from T1 is written as \\vnc{<code>}, the code coming from
t5codes.py; the narrow spaces of the model answers become ties. The escaping
mirrors #_tex of chapter7/figures/vgprint.py, which escapes the text of the
figure overlays, and extends it to the braces and the symbols of the answers.
usage: python3 flock_tables.py <lm-t5.enc> [<results directory>]
"""
import csv
import os
import sys

from t5codes import codes

T1 = set('àáâãèéêìíòóôõùúýăÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂ')
SYMBOLS = {'≈': r'$\approx$', '°': r'\textdegree{}', '→': r'$\rightarrow$', '–': '--',
           '—': '---', '&': r'\&', '%': r'\%', '$': r'\$', '#': r'\#', '_': r'\_',
           '{': r'\{', '}': r'\}', '~': r'\textasciitilde{}', '^': r'\textasciicircum{}',
           '\\': r'\textbackslash{}', '’': "'", '“': '"', '”': '"',
           ' ': '~', ' ': '~'}


def tex(s, t5):
    """Return a text as LaTeX in the encodings of the tables."""
    out = []
    for c in s:
        if c in SYMBOLS:
            out.append(SYMBOLS[c])
        elif ord(c) < 128 or c in T1:
            out.append(c)
        elif c in t5:
            out.append(rf'\vnc{{{t5[c]}}}')
        else:
            raise ValueError(f'no TeX form for {c!r} in {s!r}')
    return ''.join(out)


def cell(s, width, t5):
    """Return a text cut at the width of its column."""
    s = s.strip()
    if len(s) > width:
        return tex(s[:width].rstrip(), t5) + r'\dots'
    return tex(s, t5)


def rows(results, name):
    """Return the rows of a result file."""
    with open(os.path.join(results, f'{name}.csv'), newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


def main():
    t5 = codes(sys.argv[1])
    results = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 'results')
    print('%% tab:example1res')
    for r in rows(results, 'pipeline1'):
        geom = r['Geom'].replace('POINT (', 'POINT~(')
        print(f"{r['PointId']} & {geom} & {cell(r['PlaceDesc'], 115, t5)} \\\\")
    print('%% tab:example2res')
    for r in rows(results, 'pipeline2'):
        print(f"{tex(r['MunicipalityName'], t5)} & {cell(r['DistrictAttr'], 125, t5)} \\\\")
    print('%% tab:example3res')
    for r in rows(results, 'pipeline3'):
        print(f"{r['PointId']} & {cell(r['Place'], 105, t5)} \\\\")
    print('%% tab:example4res')
    for r in rows(results, 'pipeline4'):
        print(f"{r['VehicleType']} & {cell(r['categoryDesc'], 150, t5)} \\\\")
    print('%% tab:example5res')
    for r in rows(results, 'pipeline5_all'):
        print(f"{cell(r['Description1'], 27, t5)} & {cell(r['Description2'], 27, t5)} & "
              f"{float(r['similarity']):.4f} \\\\")


if __name__ == '__main__':
    main()
