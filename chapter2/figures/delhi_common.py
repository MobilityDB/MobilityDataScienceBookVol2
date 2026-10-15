"""Shared setup of the Delhi figures: the statements printed in chapter 2 up to each figure."""
import warnings
warnings.filterwarnings("ignore")
from datetime import timedelta
from pathlib import Path
import pandas as pd
import movingpandas as mpd

df = pd.read_csv(Path(__file__).resolve().parent.parent / '2021-01-30_all.csv', index_col=0)
tc = mpd.TrajectoryCollection(df, "deviceId", t="dateTime", x="long", y="lat")


# #select_by_positions as printed in chapter 2
def select_by_positions(tc, positions):
    subset = [tc.trajectories[i] for i in positions]
    return mpd.TrajectoryCollection(subset)


selected_positions = [1, 5, 8, 10]
my_trajs = select_by_positions(tc, selected_positions)
my_traj = tc.trajectories[1]
my_traj_split = mpd.ObservationGapSplitter(my_traj).split(gap=timedelta(minutes=20))
