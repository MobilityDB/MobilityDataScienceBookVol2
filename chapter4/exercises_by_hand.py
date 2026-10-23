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

"""The numbers of the answers of Exercises 4.3 and 4.4, worked by hand, in the
form of chapter11/exercises/by_hand.py: run it to check them."""
import math

# 4.3 (a): the rectangle [10t, 10t+2] x [0, 1] and the point (13, 1.5)
steps = 100000
nad, at = min((math.hypot(max(0.0, 13 - (10 * t + 2)), 1.5 - 1), t)
    for t in (k / steps for k in range(steps + 1)))
print("4.3 (a) nearest approach", round(nad, 3), "at the fraction", at, "of the day")
# 4.3 (b): the radius of the rectangle about its lower-left corner, and the filter of eDwithin
radius = math.hypot(2, 1)
closest_center = math.hypot(13 - 10, 1.5)
print("4.3 (b) radius", round(radius, 3), "closest position", round(closest_center, 3),
    "bound", round(1 + radius, 3), "skipped:", closest_center > 1 + radius)
# 4.3 (c): pairs of convex parts of two crosses
print("4.3 (c) disjoint", 3 * 3, "overlapping", 2 * 2)

# 4.4 (a): the yaw of a rotation about the vertical axis, (w, 0, 0, z)
yaws = [math.degrees(2 * math.atan2(z, w)) for w, z in ((0.9970, -0.0769), (0.9992, -0.0377))]
print("4.4 (a) yaws", [round(y, 1) for y in yaws], "turn", round(yaws[1] - yaws[0], 1))
# 4.4 (b): the pitch of a rotation about the y axis, (w, 0, y, 0)
print("4.4 (b) pitch", round(math.degrees(2 * math.asin(0.0401)), 2))
# 4.4 (c): the radius of the rectangle of a car of 4.6 x 1.8 m about its center
print("4.4 (c) radius", round(math.hypot(2.3, 0.9), 2))
