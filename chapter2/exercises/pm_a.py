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

import warnings; warnings.filterwarnings("ignore")
import pandas as pd
from pymeos import *
pymeos_initialize("UTC")

ais = pd.read_csv("aisinput.csv", parse_dates=["t"])
ais["instant"] = ais.apply(lambda r: TGeogPointInst(
    point=(r["longitude"], r["latitude"]), timestamp=r["t"]), axis=1)
ais["sog"] = ais.apply(lambda r: TFloatInst(value=r["sog"], timestamp=r["t"]),
    axis=1)
ships = ais.groupby("mmsi").aggregate({
    "instant": lambda x: TGeogPointSeq.from_instants(x, upper_inc=True),
    "sog": lambda x: TFloatSeq.from_instants(x, upper_inc=True),
}).rename({"instant": "trajectory"}, axis=1)

for mmsi, row in ships.iterrows():
    fast = row["sog"].at(FloatSpan(lower=10, upper=200, lower_inc=False))
    if fast is None:
        print(mmsi, "never above 10 knots")
        continue
    leg = row["trajectory"].at(fast.time())
    print(mmsi, fast.num_sequences(), fast.duration(),
          round(leg.length() / 1000, 1))
