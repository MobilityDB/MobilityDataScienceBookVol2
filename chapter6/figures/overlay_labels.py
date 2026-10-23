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

# Writes the LaTeX overlay of a map figure drawn by render_spec.py without text: the map image as a TikZ
# node, and the labels at the positions written by render_spec.py in the "labels_out" of its spec, set in
# the caption's font and size (\captionstyle) as the other map overlays of the book
# (figs/chap7/copenh_overlay.tex): the image is the node `img`, the labels are placed in the scope
# x={(img.south east)}, y={(img.north west)}, and the colours are named <pfx>c<i>. Each label carries what
# the labels of a QML style carry: it is centred on its position, keeps the text colour of its style, its background (a circle, set as a
# pill, or a rectangle in the fill colour of the style) and the angle of its baseline. A horizontal label that would
# cross the left or right edge of the figure is anchored on that edge instead of at its centre. A label
# written without a style (griddistricts_labels.json) is set as the district names, in 323232.
#   python3 overlay_labels.py <spec.json> <scale> <overlay.tex> [<image directory>=figs/chap6]
# The figure is printed at \includegraphics[scale=<scale>].
import json, os, re, sys


def _hex(c):
    """Hex of a CSS rgb()/rgba() colour or a hex string."""
    if c.startswith('#'):
        return c[1:7].upper()
    v = [int(float(x)) for x in c[c.index('(') + 1:c.index(')')].split(',')[:3]]
    return ''.join(f'{x:02X}' for x in v)


def _tex(s):
    return s.replace('&', r'\&').replace('_', r'\_').replace('%', r'\%').replace('#', r'\#')


spec_path, scale, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
imgdir = sys.argv[4] if len(sys.argv) > 4 else 'figs/chap6'
spec = json.load(open(spec_path))
labels = json.load(open(os.path.join(os.path.dirname(os.path.abspath(spec_path)), spec['labels_out'])))
img = '%s/%s' % (imgdir, spec['out'])
pfx = 'ov' + re.sub(r'[^a-z]', '', os.path.splitext(spec['out'])[0].lower())
FIG_PT = spec['width'] / spec.get('dpi', 300) * 72 * scale  # printed width of the figure in points
CHAR_PT = 4.0  # mean advance of a \captionstyle character (8.5 pt Latin Modern)
MARGIN = 0.01
cols = {}


def col(h):
    """The name of the colour."""
    h = _hex('#' + h)
    if h not in cols:
        cols[h] = f'{pfx}c{len(cols)}'
    return cols[h]


nodes = []
for l in labels:
    angle = l.get('angle', 0)
    x, anchor = l['x'], 'center'
    if not angle:
        half = len(l['text']) * CHAR_PT / FIG_PT / 2
        if x - half < MARGIN:
            x, anchor = MARGIN, 'west'
        elif x + half > 1 - MARGIN:
            x, anchor = 1 - MARGIN, 'east'
    opts = ['anchor=%s' % anchor]
    if l.get('shape') == 'circle':
        # The labelling engine reserves the text box of the label, not its background shape; a circle around
        # a long label would cover its neighbours, so the circle is a pill of the height of the text box
        # (round for one or two digits)
        opts += ['fill=%s' % col(l['fill']), 'rounded corners=4pt', 'minimum size=8pt', 'inner sep=1pt']
    elif l.get('shape') == 'rect':
        opts += ['fill=%s' % col(l['fill']), 'inner sep=1pt']
    else:
        opts.append('inner sep=0.5pt')
    if angle:
        opts.append('rotate=%g' % angle)
    opts.append('text=%s' % col(l.get('color', '323232')))
    nodes.append(r'\node[%s] at (%.4f, %.4f) {%s};' % (', '.join(opts), x, l['y'], _tex(l['text'])))

lines = ['% Written by overlay_labels.py']
lines += [r'\definecolor{%s}{HTML}{%s}%%' % (n, h) for h, n in cols.items()]
lines += [r'\begin{tikzpicture}',
          r'\node[anchor=south west, inner sep=0] (img) {\includegraphics[scale=%g]{%s}};' % (scale, img),
          r'\begin{scope}[x={(img.south east)}, y={(img.north west)}, font=\captionstyle]']
lines += nodes
lines += [r'\end{scope}', r'\end{tikzpicture}%']
open(out, 'w').write('\n'.join(lines) + '\n')
print('wrote', out, len(labels), 'labels')
