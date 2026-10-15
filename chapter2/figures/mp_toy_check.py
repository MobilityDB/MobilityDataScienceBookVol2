"""Toy MovingPandas outputs printed in chapter 2 (the trajectories with their 'Length:')."""
import pandas as pd
import geopandas as gpd
import movingpandas as mpd
from datetime import datetime
from shapely.geometry import Point

df = pd.DataFrame(
    [{"geometry": Point(0, 0), "t": datetime(2025, 1, 1, 12, 0, 0)},
     {"geometry": Point(6, 0), "t": datetime(2025, 1, 1, 12, 6, 0)},
     {"geometry": Point(6, 6), "t": datetime(2025, 1, 1, 12, 10, 0)},
     {"geometry": Point(9, 9), "t": datetime(2025, 1, 1, 12, 15, 0)}]
).set_index("t")
gdf = gpd.GeoDataFrame(df, crs=31256)
my_traj = mpd.Trajectory(gdf, 1)
print(my_traj)
segment = my_traj.get_segment_between(
    datetime(2025, 1, 1, 12, 6, 0), datetime(2025, 1, 1, 12, 12, 0))
print(segment)
df = pd.DataFrame([{'geometry': Point(0, 0), 't': datetime(2025, 1, 1, 12, 0, 0)},
                   {'geometry': Point(6, 0), 't': datetime(2025, 1, 1, 12, 0, 6)},
                   {'geometry': Point(6, 6), 't': datetime(2025, 1, 1, 12, 0, 11)},
                   {'geometry': Point(9, 9), 't': datetime(2025, 1, 1, 12, 0, 14)}]).set_index('t')
gdf = gpd.GeoDataFrame(df, crs=31256)
print(mpd.Trajectory(gdf, 1))
