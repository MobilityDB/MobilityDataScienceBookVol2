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

"""Draw the figures of the traversed area of Sect. 4.5.5 of chapter 4: two moving regions and their
traversed areas, and the three types of holes in a traversed area.

Each region is a polygon of reference moved by poses (x, y, theta): rotated by theta about the origin
of its reference coordinates, then translated by (x, y). Its traversed area is computed in the three
steps of the section: the movement is sampled at poses at most 0.05 radians apart, the position and
the angle interpolated linearly between two recorded poses; between two consecutive poses every
vertex moves along a straight segment, so that every edge sweeps the convex hull of its two
placements; these pieces and the placements are merged with unary_union. The traversed area is
drawn in blue, the placements of the region at its recorded poses in green. The pictures are written
as TikZ into $OUT (default: out/ below the working directory), as #planar_graph.py writes the panels
of the planar graph figure, which the chapter inputs: traversed_area_example.tex, hole_1.tex,
hole_2.tex and hole_3.tex. The area of each traversed area and the number of its holes are printed
on the standard error.

Usage: python3 traversed_area_figures.py
"""
import math
import os
import sys
from shapely.geometry import MultiPolygon, Polygon
from shapely.ops import unary_union

STEP = 0.05  # radians: the largest rotation between two sampled poses


def place(body, pose):
    """The vertices of the polygon body at the pose (x, y, theta)"""
    x, y, th = pose
    c, s = math.cos(th), math.sin(th)
    return [(x + c * px - s * py, y + s * px + c * py) for px, py in body]


def sampled(poses):
    """The recorded poses and, between two of them, the poses interpolated so that the region never
    turns by more than STEP"""
    out = [poses[0]]
    for (x0, y0, t0), (x1, y1, t1) in zip(poses, poses[1:]):
        k = max(1, math.ceil(abs(t1 - t0) / STEP))
        out += [(x0 + (x1 - x0) * i / k, y0 + (y1 - y0) * i / k, t0 + (t1 - t0) * i / k)
                for i in range(1, k + 1)]
    return out


def traversed(body, poses):
    """The traversed area of the polygon body (exterior ring, then the rings of its holes) moved by
    the recorded poses"""
    rings = body if isinstance(body[0][0], tuple) else [body]
    pieces = []
    seq = sampled(poses)
    for p, q in zip(seq, seq[1:]):
        for ring in rings:
            a, b = place(ring, p), place(ring, q)
            pieces += [Polygon([a[i], a[(i + 1) % len(a)], b[(i + 1) % len(b)], b[i]]).convex_hull
                       for i in range(len(a))]
    pieces += [placement(body, p) for p in seq]
    return unary_union(pieces)


def placement(body, pose):
    rings = body if isinstance(body[0][0], tuple) else [body]
    return Polygon(place(rings[0], pose), [place(r, pose) for r in rings[1:]])


# TikZ, as #planar_graph.py writes it: blue the traversed area, green the placements at the recorded
# poses, both outlined by a thin black line; holes are cut by the even-odd rule
def path(poly):
    polys = poly.geoms if isinstance(poly, MultiPolygon) else [poly]
    out = []
    for g in polys:
        for ring in [g.exterior] + list(g.interiors):
            out.append(' -- '.join('(%.4f,%.4f)' % c for c in list(ring.coords)[:-1]) + ' -- cycle')
    return ' '.join(out)


def picture(name, regions, width_cm):
    """Write the picture of the regions [(body, poses)] width_cm wide"""
    areas = [traversed(b, p) for b, p in regions]
    x0, y0, x1, y1 = unary_union(areas).bounds
    unit = width_cm / (x1 - x0)
    body = ['\\begin{tikzpicture}[x=%.4fcm, y=%.4fcm, line width=0.3pt]' % (unit, unit)]
    for a in areas:
        body.append('\\filldraw[fill=blue, draw=black, even odd rule] %s;' % path(a))
    for b, poses in regions:
        for p in poses:
            body.append('\\filldraw[fill=green!50!black, draw=black, even odd rule] %s;'
                        % path(placement(b, p)))
    body.append('\\end{tikzpicture}')
    with open(os.path.join(OUT, name + '.tex'), 'w') as fh:
        fh.write('% Generated by traversed_area_figures.py\n' + '\n'.join(body) + '\n')
    for a in areas:
        holes = sum(len(g.interiors) for g in (a.geoms if isinstance(a, MultiPolygon) else [a]))
        print(f'{name}: area {a.area:.4f}, {holes} hole(s)', file=sys.stderr)


OUT = os.environ.get('OUT', os.path.join(os.getcwd(), 'out'))
os.makedirs(OUT, exist_ok=True)

SQUARE = [(0, 0), (1, 0), (1, 1), (0, 1)]
TRIANGLE = [(0, 0), (1.3, 0), (0, 0.8)]
# A square frame 5 wide with walls 1 thick, its reference centred on the origin
FRAME = [[(-2.5, -2.5), (2.5, -2.5), (2.5, 2.5), (-2.5, 2.5)],
         [(-1.5, -1.5), (1.5, -1.5), (1.5, 1.5), (-1.5, 1.5)]]
# The L-shaped body of the section, (0 0,3 0,3 1,1 1,1 3,0 3), its reference centred on the middle of
# its bounding box
L_SHAPE = [(x - 1.5, y - 1.5) for x, y in [(0, 0), (3, 0), (3, 1), (1, 1), (1, 3), (0, 3)]]

# Fig. 4.23: a square that translates, and a triangle that turns while it moves along a bend
picture('traversed_area_example',
        [(SQUARE, [(0, 0, 0), (2, 2, 0)]),
         (TRIANGLE, [(1.2, -1.6, 0.25), (4.6, 0.6, 1.9), (4.3, 3.2, 3.3)])], 0.3 * 11.7)
# Fig. 4.25 (a): a hole of the region itself: the frame translates along its diagonal by less than its
# width, so that the points that stay inside its opening during the whole movement are never covered
picture('hole_1', [(FRAME, [(0, 0, 0), (2, 2, 0)])], 2.86)
# (b): a hole created by a non-convex region in a single movement: the L-shaped body rotates by pi
# while translating slightly, and the points close to the corner of its concavity are never covered
picture('hole_2', [(L_SHAPE, [(0, 0, 0), (0.2, 0.2, math.pi)])], 2.86)
# (c): a region that comes back to a previous position after several movements: a square goes around
# the four sides of a square path, enclosing the points it never reaches
picture('hole_3', [(SQUARE, [(0, 0, 0), (3, 0, 0), (3, 3, 0), (0, 3, 0), (0, 0, 0)])], 2.86)
