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
