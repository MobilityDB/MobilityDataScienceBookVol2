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

# Places the vector render of patterns_map.json (render_spec.py over OSM vector tiles, a PDF) as the
# map of the diagram patterns.pdf, in place of its map image /Image12: the image XObject becomes a form
# XObject holding the map's page, scaled onto the unit square the image filled, so that the diagram's
# clip rectangle and placement are kept as they are. It needs pikepdf.
#   python3 patterns_vector.py in.pdf patterns_map.pdf out.pdf
import sys
import pikepdf

src, mappdf, dst = sys.argv[1:4]
pdf = pikepdf.open(src)
page = pdf.pages[0]
xobjs = page.Resources.XObject
assert xobjs['/Image12'].Subtype == '/Image'
mp = pikepdf.open(mappdf)
form = pdf.copy_foreign(mp.pages[0].as_form_xobject())
x0, y0, x1, y1 = [float(v) for v in mp.pages[0].MediaBox]
form.BBox = [x0, y0, x1, y1]
form.Matrix = [1 / (x1 - x0), 0, 0, 1 / (y1 - y0), -x0 / (x1 - x0), -y0 / (y1 - y0)]
xobjs['/Image12'] = form
pdf.save(dst)
print('placed', mappdf, 'as /Image12', x1 - x0, y1 - y0)
