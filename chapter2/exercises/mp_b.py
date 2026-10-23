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
import pandas as pd, movingpandas as mpd
from datetime import timedelta
df = pd.read_csv("../2021-01-30_all.csv", index_col=0)
tc = mpd.TrajectoryCollection(df, "deviceId", t="dateTime", x="long", y="lat")

cleaned = mpd.OutlierCleaner(tc).clean(v_max=60, units=("km", "h"))
rows = []
for raw, cln in zip(tc, cleaned):
    raw.add_speed(overwrite=True, units=("km", "h"))
    cln.add_speed(overwrite=True, units=("km", "h"))
    rows.append([raw.id, raw.size(), cln.size(), raw.df["speed"].max(),
                 cln.df["speed"].max(), raw.get_length() / 1000,
                 cln.get_length() / 1000])
res = pd.DataFrame(rows, columns=["bus", "n", "n_clean", "vmax", "vmax_clean",
                                  "km", "km_clean"]).set_index("bus")
print(res.round(1))
