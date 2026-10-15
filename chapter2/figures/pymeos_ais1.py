# PyMEOS/MovingPandas AIS example of chapter 2 (aisinput.csv), code as printed in the chapter.
# #extract_wkt_from_traj_vectorized and #create_point are the functions printed in the chapter
# (create_point also in PyMEOS-Examples "MovingPandas - PyMEOS - AIS.ipynb"). Writes the points
# of the two simplified trajectories to pymeosais1_a.gpkg and pymeosais1_b.gpkg.
import os
from pathlib import Path

DATA = Path(os.environ.get('CH2_DATA', Path(__file__).resolve().parent / 'data'))  # input data, see README.md
import geopandas as gpd
import movingpandas as mpd
import pandas as pd
from pymeos import pymeos_initialize, TGeogPointSeq, TGeogPointInst, TPointInst

pymeos_initialize()


def extract_wkt_from_traj_vectorized(traj):
    series = traj.df.geometry.to_wkt() + '@' + traj.df.geometry.index.astype(str)
    return str(list(series)).replace("'", "")


df = pd.read_csv(f'{DATA}/aisinput.csv')
gdf = gpd.GeoDataFrame(df.drop(['latitude', 'longitude'], axis=1),
                       geometry=gpd.points_from_xy(df.longitude, df.latitude), crs=4326)
tcoll = mpd.TrajectoryCollection(gdf, 'mmsi', t='t')
print([t.id for t in tcoll.trajectories])
original_traj = tcoll.trajectories[1]
print(original_traj)

wkt = extract_wkt_from_traj_vectorized(original_traj)
sequence = TGeogPointSeq(string=wkt)
print("string ctor", repr(sequence)[:300], sequence.num_instants())

instants = wkt[1:-1].split(', ')
sequence = TGeogPointSeq(instant_list=instants, normalize=False)
sequenceNorm = TGeogPointSeq(instant_list=instants, normalize=True)
print(repr(sequence)[:300])
print(repr(sequenceNorm)[:300])
print("sequence.length()", sequence.length())
print("sequence.num_instants()", sequence.num_instants())
print("sequenceNorm.length()", sequenceNorm.length())
print("sequenceNorm.num_instants()", sequenceNorm.num_instants())
print("reduction %", 100 * (1 - sequenceNorm.num_instants() / sequence.num_instants()))

pymeos_simplified = sequence.simplify_douglas_peucker(synchronized=True, distance=0.005)
exportedPymeosMp = mpd.Trajectory(pymeos_simplified.to_geometric().to_dataframe(), 1)
print("pymeos_simplified", exportedPymeosMp)
exportedPymeosMp.to_point_gdf().to_file(f"{DATA}/pymeosais1_a.gpkg")

traj = mpd.Trajectory(sequence.to_geometric().to_dataframe(), 1)
mpd_generalized = mpd.TopDownTimeRatioGeneralizer(traj).generalize(tolerance=0.005)
print("mpd_generalized", mpd_generalized)
print("mpd_generalized columns", list(mpd_generalized.df.columns))
mpd_generalized.to_point_gdf().to_file(f"{DATA}/pymeosais1_b.gpkg")


def create_point(row) -> TPointInst:
    return TGeogPointInst(string=f"{row['geometry']}@{row.name}")


original_traj.df['MEOS Point'] = original_traj.df.apply(create_point, axis=1)
sequence = TGeogPointSeq(instant_list=original_traj.df['MEOS Point'], normalize=False)
dp_simplified_pymeos = sequence.simplify_douglas_peucker(synchronized=True, distance=0.001)
dp_simplified_mp = mpd.Trajectory(dp_simplified_pymeos.to_geometric().to_dataframe(),
                                  traj_id=219026257)
mp_generalized = mpd.DouglasPeuckerGeneralizer(original_traj).generalize(tolerance=0.001)
print("dp_simplified_mp", dp_simplified_mp.size(), dp_simplified_mp.get_length())
print("mp_generalized", mp_generalized.size(), mp_generalized.get_length())
print("ratio", mp_generalized.size() / dp_simplified_mp.size())
