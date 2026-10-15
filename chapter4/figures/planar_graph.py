"""Draw the three panels of the planar graph figure of Sect. 4.5.5 of chapter 4.

Computes the area an L-shaped body traverses between two placements as the
section describes it: the segments (the edges of both placements and the paths
of the vertices), the planar graph they form once split at their intersections,
and the walk along its outer boundary. The coordinates are exact fractions. The
walk is checked against the union of the two placements and of the
parallelograms swept by the edges, and the counts and areas are printed on the
standard error. The three panels are written as TikZ pictures into $OUT
(default: out/ below the working directory): planar_graph_segments.tex,
planar_graph_graph.tex and planar_graph_walk.tex, which the chapter inputs as
the subfloats of the figure.

Usage: python3 planar_graph.py
"""
import math, os, sys
from fractions import Fraction as F
from shapely.geometry import Polygon
from shapely.ops import unary_union

BODY = [(0, 0), (3, 0), (3, 1), (1, 1), (1, 3), (0, 3)]
MOVE = (F(3, 2), F(-1, 2))                     # translation between the two placements
A = [(F(x), F(y)) for x, y in BODY]
B = [(x + MOVE[0], y + MOVE[1]) for x, y in A]
n = len(A)
segs = [(A[i], A[(i + 1) % n], 'edgeA') for i in range(n)] + \
       [(B[i], B[(i + 1) % n], 'edgeB') for i in range(n)] + \
       [(A[i], B[i], 'path') for i in range(n)]

def inter(s, t):
    (p1, p2), (p3, p4) = s, t
    d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
    if d == 0:
        return None
    u = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d
    v = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d
    if 0 <= u <= 1 and 0 <= v <= 1:
        return (p1[0] + u * (p2[0] - p1[0]), p1[1] + u * (p2[1] - p1[1]))
    return None

# split every segment at the points lying on it
pts_on = [set([s[0], s[1]]) for s in segs]
for i in range(len(segs)):
    for j in range(i + 1, len(segs)):
        p = inter(segs[i][:2], segs[j][:2])
        if p is not None:
            pts_on[i].add(p); pts_on[j].add(p)
vertices = set(A) | set(B)
crossings = set().union(*pts_on) - vertices
adj = {}
for (a, b, kind), ps in zip(segs, pts_on):
    key = lambda p: (p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])
    ps = sorted(ps, key=key)
    for p, q in zip(ps, ps[1:]):
        adj.setdefault(p, set()).add(q); adj.setdefault(q, set()).add(p)
edges = {frozenset((p, q)) for p in adj for q in adj[p]}

# walk the outer boundary: start at the leftmost (then lowest) node; at each node, list its neighbors
# counterclockwise starting from the direction back to the previous node, and take the first one
start = min(adj, key=lambda p: (p[0], p[1]))
ang = lambda p, q: math.atan2(float(q[1] - p[1]), float(q[0] - p[0]))
walk = [start]; cur = start; prev = None
while True:
    back = ang(cur, prev) if prev is not None else -math.pi / 2
    def ccw(q):
        a = (ang(cur, q) - back) % (2 * math.pi)
        return a if a > 1e-12 else 2 * math.pi
    nxt = min((q for q in adj[cur] if q != prev or len(adj[cur]) == 1), key=ccw)
    prev, cur = cur, nxt
    if cur == start:
        break
    walk.append(cur)
area_walk = Polygon([(float(x), float(y)) for x, y in walk])

# independent check: the body translates, so it sweeps the union of its two placements and of the
# parallelograms its edges sweep
pa = [(float(x), float(y)) for x, y in A]; pb = [(float(x), float(y)) for x, y in B]
pieces = [Polygon(pa), Polygon(pb)] + [Polygon([pa[i], pa[(i + 1) % n], pb[(i + 1) % n], pb[i]]).buffer(0)
                                      for i in range(n)]
swept = unary_union(pieces)
print('segments', len(segs), 'vertices', len(vertices), 'crossings', len(crossings),
      'nodes', len(adj), 'graph edges', len(edges), 'boundary nodes', len(walk), file=sys.stderr)
print('walk area', area_walk.area, 'swept area', swept.area, 'symdiff', area_walk.symmetric_difference(swept).area,
      'holes in swept', len(getattr(swept, 'interiors', [])), file=sys.stderr)
print('crossings', sorted((float(x), float(y)) for x, y in crossings), file=sys.stderr)
print('walk', [(float(x), float(y)) for x, y in walk], file=sys.stderr)

# TikZ: one picture per panel, for the three subfloats of the figure
f = lambda p: '(%.3f,%.3f)' % (float(p[0]), float(p[1]))
poly = lambda P: ' -- '.join(f(p) for p in P) + ' -- cycle'
pic = lambda body: '\\begin{tikzpicture}[scale=0.6]\n' + '\n'.join(body) + '\n\\end{tikzpicture}\n'
# A light grid of the plane behind every panel, so that the drawing reads as a movement in the plane
# and not as an oblique view of a solid
GRID = ['\\draw[gray!55, thin] (-0.5,-1) grid (5,3.5);']
TICKS = ['\\node[font=\\tiny, gray!80!black, below] at (%d,-1) {%d};' % (x, x) for x in range(0, 6)] + \
        ['\\node[font=\\tiny, gray!80!black, left] at (-0.5,%d) {%d};' % (y, y) for y in range(0, 4)]
# the body at two instants between A and B, as faint outlines
GHOSTS = ['\\draw[green!45!black, densely dotted] %s;' % poly([(x + MOVE[0] * k / 3, y + MOVE[1] * k / 3) for x, y in A])
          for k in (1, 2)]
pa_ = GRID + TICKS + ['\\fill[green!25] %s;' % poly(A), '\\fill[green!25, opacity=0.8] %s;' % poly(B)] + GHOSTS + \
      ['\\draw[thick, green!40!black] %s;' % poly(A), '\\draw[thick, green!40!black] %s;' % poly(B)]
pa_ += ['\\draw[dashed, ->, >=stealth, gray!80!black] %s -- %s;' % (f(A[i]), f(B[i])) for i in range(n)]
pa_ += ['\\node[font=\\small] at (0.5,2.3) {$A$};', '\\node[font=\\small] at (4.0,0.0) {$B$};']
pb_ = GRID + ['\\fill[green!10] %s;' % poly(A), '\\fill[green!10] %s;' % poly(B)]
pb_ += ['\\draw[black, semithick] %s -- %s;' % (f(min(e)), f(max(e))) for e in sorted(edges, key=lambda e: sorted(e))]
pb_ += ['\\fill[black] %s circle (2.2pt);' % f(p) for p in sorted(vertices)]
pb_ += ['\\fill[red] %s circle (2.6pt);' % f(p) for p in sorted(crossings)]
pc_ = GRID + ['\\fill[blue!20] %s;' % poly(walk)]
pc_ += ['\\draw[blue!45!gray, densely dashed] %s -- %s;' % (f(min(e)), f(max(e))) for e in sorted(edges, key=lambda e: sorted(e))]
pc_ += ['\\draw[very thick, blue!70!black] %s;' % poly(walk)]
pc_ += ['\\node[circle, fill=white, draw, inner sep=0.5pt, font=\\scriptsize] at %s {%d};' % (f(p), i + 1)
        for i, p in enumerate(walk)]
OUT = os.environ.get('OUT', os.path.join(os.getcwd(), 'out'))
os.makedirs(OUT, exist_ok=True)
for name, body in (('planar_graph_segments', pa_), ('planar_graph_graph', pb_), ('planar_graph_walk', pc_)):
    with open(os.path.join(OUT, name + '.tex'), 'w') as fh:
        fh.write('% Generated by planar_graph.py\n' + pic(body))
