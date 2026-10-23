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

"""The numbers of the answers of Exercises 11.1, 11.3, 11.4, and 11.5, which are
worked by hand: run it to check them."""
import math

# Exercise 11.1 (b): frequencies of the rotary embedding for a head of 32 dimensions
dh = 32
theta = [10000 ** (-2 * k / dh) for k in range(dh // 2)]
print("11.1 largest", theta[0], "smallest", f"{theta[-1]:.3g}",
    "full turn", round(2 * math.pi / theta[-1]))

# Exercise 11.3: the encoder, L = 6 layers of width d = 128, H = 4 heads, d_ff = 512
L, d, H, dff, n = 6, 128, 4, 512, 256
att, ffn = 4 * d * d, 2 * d * dff
print("11.3 (a) attention", att, "feed-forward", ffn, "layer", att + ffn,
    "stack", L * (att + ffn), f"share {L * (att + ffn) / 1355018:.0%}")
print("11.3 (b) scores", n * n * H * L, "doubled", (2 * n) ** 2 * H * L)
print("11.3 (c) d_h", d // H, f"sqrt {math.sqrt(d // H):.2f}")

# Exercise 11.4 (a): a trip of 30 minutes from Saturday 23:50, Monday = 0
dtn = lambda t: math.log(1 + t) / math.log(1 + 1800)
print("11.4 (a) 23:59", [round(x, 3) for x in (5 / 6, 23 / 23, 59 / 59, dtn(540))],
    "00:05", [round(x, 3) for x in (6 / 6, 0 / 23, 5 / 59, dtn(900))])
# Exercise 11.4 (b): speed / 30 clipped to [0, 1], course / 180 - 1, rate of turn / 720
print("11.4 (b)", round(12.7 / 30, 3), 270 / 180 - 1, round(-30 / 720, 3), "35 kn",
    round(35 / 30, 2), "clipped to", min(35 / 30, 1))

# Exercise 11.5 (a): masked positions of a trajectory of 200 positions, per mode
modes = {"spatial-random": (0.30, 100), "block": (0.15, 0.25 * 200),
    "key-point": (0.15, 0.15 * 198), "kinematic-group": (0.05, 100),
    "semantic-group": (0.05, 100), "last-N": (0.30, 10)}
print("11.5 (a)", {m: c for m, (_, c) in modes.items()},
    "average", round(sum(p * c for p, c in modes.values()), 1))
# Exercise 11.5 (b): the weighted loss
w, mse = [5, 5, 1, 0.25, 0.25, 0.25], [0.01, 0.01, 0.02, 0.2, 0.2, 0.2]
num = sum(a * b for a, b in zip(w, mse))
print("11.5 (b) loss", round(num / sum(w), 3),
    f"kinematic share {sum(a * b for a, b in zip(w[3:], mse[3:])) / num:.0%}")
