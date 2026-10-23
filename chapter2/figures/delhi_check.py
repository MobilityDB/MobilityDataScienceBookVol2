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

"""Every output printed in the MovingPandas Delhi section of chapter 2, recomputed."""
from pathlib import Path
import pandas as pd, movingpandas as mpd
from datetime import timedelta
print("movingpandas", mpd.__version__)
df = pd.read_csv(Path(__file__).resolve().parent.parent / '2021-01-30_all.csv', index_col=0)
print(f"Finished reading {len(df)} records.")
tc = mpd.TrajectoryCollection(df, "deviceId", t="dateTime", x="long", y="lat")
print(tc)


# #select_by_positions as printed in chapter 2
def select_by_positions(tc, positions):
    subset = [tc.trajectories[i] for i in positions]
    return mpd.TrajectoryCollection(subset)


my_trajs = select_by_positions(tc, [1, 5, 8, 10])
print(my_trajs)
my_traj = tc.trajectories[1]
print(my_traj)
my_traj_split = mpd.ObservationGapSplitter(my_traj).split(gap=timedelta(minutes=30))
print(my_traj_split)
split = mpd.StopSplitter(my_traj).split(max_diameter=30, min_duration=timedelta(minutes=1), min_length=500)
print("StopSplitter", split)
my_split_speed = mpd.SpeedSplitter(my_traj).split(speed=1, duration=timedelta(minutes=5))
print("SpeedSplitter", my_split_speed)
original_traj = my_traj_split.trajectories[1]
print(original_traj)
print("DP", mpd.DouglasPeuckerGeneralizer(original_traj).generalize(tolerance=0.001))
print("MTD", mpd.MinTimeDeltaGeneralizer(original_traj).generalize(tolerance=timedelta(minutes=1)))
print("TDTR", mpd.TopDownTimeRatioGeneralizer(original_traj).generalize(tolerance=0.001))
my_traj_stop = my_traj_split.trajectories[2]
detector = mpd.TrajectoryStopDetector(my_traj_stop)
for x in detector.get_stop_time_ranges(min_duration=timedelta(seconds=60), max_diameter=100):
    print(x)
detector = mpd.TrajectoryStopDetector(my_trajs)
stop_points = detector.get_stop_points(min_duration=timedelta(seconds=120), max_diameter=100)
print("len(stop_points)", len(stop_points))
split_tr = mpd.ObservationGapSplitter(tc).split(gap=timedelta(minutes=15))
smooth = mpd.KalmanSmootherCV(split_tr).smooth(process_noise_std=0.1, measurement_noise_std=10)
print(smooth)
