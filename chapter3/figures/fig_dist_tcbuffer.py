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

"""Write the TikZ of Fig. dist_tcbuffer of chapter 3, the turning points of
the temporal distance of a temporal circular buffer, which the chapter holds
inline in its figure environment.

(a) The temporal circular buffer [Cbuffer(Point(4 4),2)@2001-01-01,
Cbuffer(Point(16 15),5)@2001-01-04] and the point q = (14 3): the circle at the
turning point, the end of the shortest line, and the fraction of the interval
at which the turning point lies, as MobilityDB answers them
(nearestApproachInstant, valueAtTimestamp and shortestLine).
(b) The temporal circular buffers [Cbuffer(Point(4 16),2)@2001-01-01,
Cbuffer(Point(16 4),2)@2001-01-03] (red, the first argument) and
[Cbuffer(Point(4 4),2)@2001-01-01, Cbuffer(Point(16 16),2)@2001-01-03]
(blue): the fractions of the interval at which they begin and stop touching,
the instants of their temporal distance whose value is 0.
Both panels share one frame, FRAME: the plane from 0 to 22 at 0.21 cm a unit,
with a grid every 2.5 and ticks every 5.

The answers are passed on the command line, so that the figure draws what the
database computes. The pictures are written to dist_tcbuffer_a.tex and
dist_tcbuffer_b.tex in <outdir>; given the chapter, each is compared with the
tikzpicture the chapter holds for it, and a difference is reported with exit
status 1. Like overlay_excerpt.py (#overlay_excerpt) it writes the LaTeX of a
figure of the book; external_tangents (#external_tangents) and toward
(#to_q) are those of the matplotlib drawing of panel (a) this script replaces.

usage: python3 fig_dist_tcbuffer.py <outdir> <cx> <cy> <r> <lx> <ly> <frac>
         <frac_in> <frac_out> [<chapter3.tex>]
"""
import math
import os
import sys

# (a): the buffer at its two instants and the point
C1, R1, C2, R2, Q = (4, 4), 2, (16, 15), 5, (14, 3)
# (b): the two buffers, red then blue, from their first to their last instant
RED, BLUE, RAD = ((4, 16), (16, 4)), ((4, 4), (16, 16)), 2
BLUECOL = 'RoyalBlue!75!black'
# The frame of both panels
FRAME = [
    r'  \draw[gray!25, very thin, step=2.5] (0,0) grid (22,22);',
    r'  \draw[very thin] (0,0) rectangle (22,22);',
    r'  \foreach \x in {0,5,...,20} {\draw[very thin] (\x,0) -- (\x,-0.25) node[below, inner sep=1.5pt] {\x};}',
    r'  \foreach \y in {0,5,...,20} {\draw[very thin] (0,\y) -- (-0.25,\y) node[left, inner sep=1.5pt] {\y};}']


def num(v):
    """A coordinate with three decimals, written shorter when the value is
    exact with fewer, as 2.4 or 12, as the chapter writes the coordinates of
    its figure #fig_dist_tcbuffer; no other writer of the companion formats
    TikZ coordinates (#overlay_excerpt writes centimeters of its own)"""
    s = '%.3f' % v
    short = s.rstrip('0').rstrip('.')
    if abs(float(short) - v) < 1e-9:
        s = short
    return '0' if s == '-0' else s


def pt(p):
    """A point as TikZ writes it"""
    return '(%s,%s)' % (num(p[0]), num(p[1]))


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


def toward(c, rad):
    """The point of the circle (c, rad) on the line from its center to q"""
    d = math.hypot(Q[0] - c[0], Q[1] - c[1])
    return (c[0] + rad * (Q[0] - c[0]) / d, c[1] + rad * (Q[1] - c[1]) / d)


def side_lines(seg, rad):
    """The two lines swept by the sides of a circle of radius rad moving along seg"""
    (x0, y0), (x1, y1) = seg
    d = math.hypot(x1 - x0, y1 - y0)
    nx, ny = -(y1 - y0) / d * rad, (x1 - x0) / d * rad
    return [((x0 + s * nx, y0 + s * ny), (x1 + s * nx, y1 + s * ny)) for s in (1, -1)]


def at(seg, f):
    """The point at the fraction f of the segment seg"""
    (x0, y0), (x1, y1) = seg
    return (x0 + f * (x1 - x0), y0 + f * (y1 - y0))


def picture_a(cx, cy, r, lx, ly, frac):
    """The tikzpicture of panel (a)"""
    c, l = (cx, cy), (lx, ly)
    t1, t2 = external_tangents(C1, R1, C2, R2)
    a1, a2 = toward(C1, R1), toward(C2, R2)
    return '\n'.join([
        r'{\begin{tikzpicture}[x=0.21cm, y=0.21cm]',
        r'  % Cbuffer(Point(4 4), 2) at t_i and Cbuffer(Point(16 15), 5) at t_{i+1}, and the point',
        r'  %% q = (14 3); the turning point is at the fraction %.4f of the interval' % frac]
        + FRAME + [
        r'  \begin{scope}[%s, thin]' % BLUECOL,
        r'  \draw %s -- %s %s -- %s;' % (pt(t1[0]), pt(t1[1]), pt(t2[0]), pt(t2[1])),
        r'  \filldraw[fill=%s, fill opacity=0.18] %s circle[radius=%s];' % (BLUECOL, pt(C1), num(R1)),
        r'  \filldraw[fill=%s, fill opacity=0.18] %s circle[radius=%s];' % (BLUECOL, pt(C2), num(R2)),
        r'  \draw[densely dotted] %s circle[radius=%s];' % (pt(c), num(r)),
        r'  \end{scope}',
        r'  \draw[densely dotted] %s -- %s %s -- %s;' % (pt(C1), pt(a1), pt(C2), pt(a2)),
        r'  \draw[red, densely dotted] %s -- %s;' % (pt(c), pt(l)),
        r'  \draw[thick] %s -- %s %s -- %s;' % (pt(Q), pt(a1), pt(Q), pt(a2)),
        r'  \draw[red, thick] %s -- %s;' % (pt(Q), pt(l)),
        r'  \foreach \p in {%s, %s, %s} {\fill \p circle[radius=1.2pt];}' % (pt(C1), pt(C2), pt(Q)),
        r'  \fill[red] %s circle[radius=1.5pt];' % pt(c),
        r'  \node[below, inner sep=2pt] at %s {$p_i$};' % pt(C1),
        r'  \node[below, inner sep=2pt] at %s {$p_{i+1}$};' % pt(C2),
        r'  \node[red, above, inner sep=2pt] at %s {$t$};' % pt(c),
        r'  \node[below, inner sep=2pt] at %s {$q$};' % pt(Q),
        r'\end{tikzpicture}}'])


def buffer_b(seg, color, f_in, f_out):
    """The lines of one buffer of panel (b)"""
    s1, s2 = side_lines(seg, RAD)
    p_in, p_out = at(seg, f_in), at(seg, f_out)
    r = num(RAD)
    return [
        r'  \begin{scope}[%s, thin]' % color,
        r'  \draw %s -- %s %s -- %s;' % (pt(s1[0]), pt(s1[1]), pt(s2[0]), pt(s2[1])),
        r'  \draw[densely dotted] %s -- %s;' % (pt(seg[0]), pt(seg[1])),
        r'  \filldraw[fill opacity=0.18] %s circle[radius=%s]; \filldraw[fill opacity=0.18] %s circle[radius=%s];'
        % (pt(seg[0]), r, pt(seg[1]), r),
        r'  \draw[densely dotted] %s circle[radius=%s]; \draw[densely dotted] %s circle[radius=%s];'
        % (pt(p_in), r, pt(p_out), r),
        r'  \foreach \p in {%s, %s, %s, %s} {\fill \p circle[radius=1.2pt];}'
        % (pt(seg[0]), pt(seg[1]), pt(p_in), pt(p_out)),
        r'  \end{scope}']


def picture_b(f_in, f_out):
    """The tikzpicture of panel (b)"""
    b_in, b_out = at(BLUE, f_in), at(BLUE, f_out)
    r_in, r_out = at(RED, f_in), at(RED, f_out)
    return '\n'.join([
        r'{\begin{tikzpicture}[x=0.21cm, y=0.21cm]',
        r'  % From 2001-01-01 to 2001-01-03, the blue buffer moves from (4 4) to (16 16) and the red one',
        r'  % from (4 16) to (16 4), both of radius 2; they touch at 16:00 on January 1 and at 8:00 on',
        r'  % January 2, the turning points']
        + FRAME + buffer_b(BLUE, BLUECOL, f_in, f_out) + buffer_b(RED, 'red', f_in, f_out) + [
        r'  \node[red, below, inner sep=2pt] at %s {$p_i$};' % pt(RED[0]),
        r'  \node[red, below, inner sep=2pt] at %s {$p_{i+1}$};' % pt(RED[1]),
        r'  \node[%s, below, inner sep=2pt] at %s {$q_i$};' % (BLUECOL, pt(BLUE[0])),
        r'  \node[%s, below, inner sep=2pt] at %s {$q_{i+1}$};' % (BLUECOL, pt(BLUE[1])),
        r'  \foreach \p in {%s, %s} {\node[below, inner sep=2pt] at \p {$t_\mathit{in}$};}' % (pt(b_in), pt(r_in)),
        r'  \foreach \p in {%s, %s} {\node[below, inner sep=2pt] at \p {$t_\mathit{out}$};}' % (pt(b_out), pt(r_out)),
        r'\end{tikzpicture}}'])


def in_chapter(text, head):
    """The tikzpicture of the chapter that begins with the lines head (its
    opening line, which both panels share, and the comment naming its
    example), or None when the chapter holds none; no other script of the
    companion reads the LaTeX of the chapter, the nearest being
    #overlay_excerpt, which writes it"""
    i = text.find(head + '\n')
    if i < 0:
        return None
    end = r'\end{tikzpicture}}'
    return text[i:text.index(end, i) + len(end)]


def main():
    if len(sys.argv) not in (10, 11):
        sys.exit(__doc__)
    outdir = sys.argv[1]
    cx, cy, r, lx, ly, frac, f_in, f_out = map(float, sys.argv[2:10])
    pictures = {'a': picture_a(cx, cy, r, lx, ly, frac), 'b': picture_b(f_in, f_out)}
    for k, tikz in pictures.items():
        path = os.path.join(outdir, 'dist_tcbuffer_%s.tex' % k)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(tikz + '\n')
        print('wrote', path)
    if len(sys.argv) == 11:
        text = open(sys.argv[10], encoding='utf-8').read()
        bad = 0
        for k, tikz in pictures.items():
            same = in_chapter(text, '\n'.join(tikz.split('\n', 2)[:2])) == tikz
            print('panel (%s) %s the one of %s' % (k, 'is' if same else 'differs from', sys.argv[10]))
            bad |= not same
        sys.exit(bad)


if __name__ == '__main__':
    main()
