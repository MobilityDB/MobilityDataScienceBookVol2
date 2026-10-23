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

"""The numbers of the answers of Exercises 9.4 and 9.5, worked by hand on the
rules of the flights stream, in the form of chapter11/exercises/by_hand.py: run
it to check them."""
from datetime import datetime, timedelta

# 9.4 (c): the segment between two hours, at 230 m/s with a report every 10 s
print("9.4 (c) per boundary at most", 230 * 10, "m, on average", 230 * 10 / 2,
    "m; two boundaries", 2 * 230 * 10, "m")

# 9.5 (a): the reachability rule at 400 m/s against the last kept report
reports = [0, 8, 15, 25, 30]
dist = {(0, 8): 2000, (8, 15): 50000, (8, 25): 4500, (25, 30): 9000}
kept = [0]
for t in reports[1:]:
    speed = dist[(kept[-1], t)] / (t - kept[-1])
    print(f"9.5 (a) {t} s from {kept[-1]} s: {speed:.0f} m/s",
        "kept" if speed <= 400 else "removed")
    if speed <= 400:
        kept.append(t)
print("9.5 (a) kept", kept)

# 9.5 (b): the watermark is the largest report time seen minus 30 s
seen = datetime(2026, 3, 1, 6, 0, 35)
watermark = seen - timedelta(seconds=30)
print("9.5 (b) watermark", watermark.time(), "window [05:00, 06:00) emitted:",
    watermark > datetime(2026, 3, 1, 6, 0))

# 9.5 (c): the seed waits for the eleventh report, at one report every 10 s
print("9.5 (c) first report held back", (11 - 1) * 10, "s")
