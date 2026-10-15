# Builds aisinput.csv (columns t, mmsi, latitude, longitude, sog) with the cleaned records
# of five vessels of the DMA file aisdk-2026-01-20, ordered by timestamp.
import os
from pathlib import Path

DATA = Path(os.environ.get('CH2_DATA', Path(__file__).resolve().parent / 'data'))  # input data, see README.md
import pandas as pd

MMSIS = [219001013, 219026257, 219033720, 220076700, 265703000]
ais = pd.read_parquet(f"{DATA}/ais_filtered.parquet",
                      filters=[("mmsi", "in", MMSIS)])
out = ais.rename(columns={"lat": "latitude", "lon": "longitude"})
out = out.sort_values(["t", "mmsi"])[["t", "mmsi", "latitude", "longitude", "sog"]]
out.to_csv(f"{DATA}/aisinput.csv", index=False)
print(len(out))
print(out.groupby("mmsi").size())
