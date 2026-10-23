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
import pandas as pd, geopandas as gpd, movingpandas as mpd
from datetime import timedelta
df = pd.read_csv("aisinput.csv")
gdf = gpd.GeoDataFrame(df.drop(["latitude", "longitude"], axis=1),
    geometry=gpd.points_from_xy(df.longitude, df.latitude), crs=4326)
ships = mpd.TrajectoryCollection(gdf, "mmsi", t="t")

detector = mpd.TrajectoryStopDetector(ships)
stops = detector.get_stop_points(min_duration=timedelta(minutes=30),
                                 max_diameter=200)
stops["mmsi"] = stops["traj_id"].astype(str)
print(stops.groupby("mmsi").agg(stops=("duration_s", "count"),
      hours=("duration_s", lambda s: round(s.sum() / 3600, 1))))
moving = mpd.StopSplitter(ships).split(max_diameter=200,
    min_duration=timedelta(minutes=30), min_length=500)
print(moving)
for t in moving:
    print(t.id, t.get_end_time(), round(t.get_length() / 1000, 1))
