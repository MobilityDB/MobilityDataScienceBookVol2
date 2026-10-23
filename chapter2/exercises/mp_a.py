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

legs = mpd.ObservationGapSplitter(tc).split(gap=timedelta(minutes=20))
print(legs)
stats = legs.to_traj_gdf()
stats["bus"] = stats["deviceId"].str.split("_").str[0]
stats["km"] = stats["length"] / 1000
stats["hours"] = [t.get_duration() / timedelta(hours=1) for t in legs]
summary = stats.groupby("bus").agg(legs=("km", "count"),
    total_km=("km", "sum"), longest_km=("km", "max"), hours=("hours", "sum"))
print(summary.round(1))
