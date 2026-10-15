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
