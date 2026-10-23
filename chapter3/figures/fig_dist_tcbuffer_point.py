#!/usr/bin/env python3
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

"""Draw Fig. dist_tcbuffer_point of chapter 3: the temporal circular buffer
[Cbuffer(Point(4 4),2)@2001-01-01, Cbuffer(Point(16 15),5)@2001-01-04], the
point q = (14 3), and the circular buffer at the turning point of their
temporal distance, with the elements of the figure it replaces.

The circle at the turning point and the end of the shortest line are those
MobilityDB master answers (nearestApproachInstant, valueAtTimestamp and
shortestLine of the listing of the chapter), passed on the command line so
that the figure draws what the database computes.

usage: python3 fig_dist_tcbuffer_point.py <cx> <cy> <r> <lx> <ly> <out.pdf>
"""
import math
import sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

cx, cy, r, lx, ly = map(float, sys.argv[1:6])
OUT = sys.argv[6]
C1, R1 = (4.0, 4.0), 2.0
C2, R2 = (16.0, 15.0), 5.0
Q = (14.0, 3.0)
BLUE, RED, GREEN = '#3b7dbf', '#e0103a', 'green'

def external_tangents(c1, r1, c2, r2):
    """The two external tangent segments of two circles, as point pairs"""
    dx, dy = c2[0] - c1[0], c2[1] - c1[1]
    d = math.hypot(dx, dy)
    theta = math.atan2(dy, dx)
    delta = math.acos((r1 - r2) / d)
    segs = []
    for s in (1, -1):
        a = theta + s * delta
        segs.append(((c1[0] + r1 * math.cos(a), c1[1] + r1 * math.sin(a)),
                     (c2[0] + r2 * math.cos(a), c2[1] + r2 * math.sin(a))))
    return segs

def to_q(ax, c, rad, color):
    """The line from a center to q, dotted inside its circle"""
    d = math.hypot(Q[0] - c[0], Q[1] - c[1])
    ux, uy = (Q[0] - c[0]) / d, (Q[1] - c[1]) / d
    e = (c[0] + rad * ux, c[1] + rad * uy)
    ax.plot([c[0], e[0]], [c[1], e[1]], ':', color=color, lw=1.0)
    ax.plot([e[0], Q[0]], [e[1], Q[1]], '-', color=color, lw=1.6)

fig, ax = plt.subplots(figsize=(5.2, 5.2))
for (a, b) in external_tangents(C1, R1, C2, R2):
    ax.plot([a[0], b[0]], [a[1], b[1]], '-', color=BLUE, lw=0.6)
for c, rad in ((C1, R1), (C2, R2)):
    ax.add_patch(plt.Circle(c, rad, fill=False, color=BLUE, lw=1.4))
ax.add_patch(plt.Circle((cx, cy), r, fill=False, color=RED, lw=1.4, ls='--'))
to_q(ax, C1, R1, GREEN)
to_q(ax, C2, R2, GREEN)
ax.plot([cx, lx], [cy, ly], ':', color=RED, lw=1.0)
ax.plot([lx, Q[0]], [ly, Q[1]], '-', color=RED, lw=1.6)
for c in (C1, C2, Q):
    ax.plot(*c, 'o', color='black', ms=3)
ax.plot(cx, cy, 'o', color=RED, ms=5, label='Turning point')
box = dict(boxstyle='round,pad=0.2', fc='white', ec='0.8')
ax.annotate('$t_i$', C1, xytext=(-8, 8), textcoords='offset points', fontsize=12, bbox=box)
ax.annotate('$t_{i+1}$', C2, xytext=(-8, 8), textcoords='offset points', fontsize=12, bbox=box)
ax.annotate('$t$', (cx, cy), xytext=(-8, 8), textcoords='offset points', fontsize=12, bbox=box)
ax.annotate('$q$', Q, xytext=(4, -16), textcoords='offset points', fontsize=12, bbox=box)
ax.set_xlim(0, 22); ax.set_ylim(0, 22.5); ax.set_aspect('equal')
ax.set_xlabel('X axis'); ax.set_ylabel('Y axis')
ax.grid(ls='-.', lw=0.5, color='0.6')
ax.legend(loc='upper left', fontsize=10)
fig.tight_layout()
fig.savefig(OUT)
print('wrote', OUT)
