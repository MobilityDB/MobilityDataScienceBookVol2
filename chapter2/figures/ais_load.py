# Pandas part of the complete PyMEOS example of chapter 2, run on the DMA file of January 20,
# 2026 (aisdk-2026-01-20.csv). Saves the filtered frame for the next steps.
import os
from pathlib import Path

DATA = Path(os.environ.get('CH2_DATA', Path(__file__).resolve().parent / 'data'))  # input data, see README.md
import pandas as pd

ais = pd.read_csv(
    f"{DATA}/aisdk-2026-01-20.csv",
    usecols=["# Timestamp", "MMSI", "Latitude", "Longitude", "SOG"],
)
print("raw rows", len(ais))
ais.columns = ["t", "mmsi", "lat", "lon", "sog"]
ais = ais[ais["t"] != 0]
ais["t"] = pd.to_datetime(ais["t"], format='%d/%m/%Y %H:%M:%S')
ais = ais[ais["mmsi"] != 0]
ais = ais.drop_duplicates(["t", "mmsi"])
ais = ais[(ais["lat"] >= 40.18) & (ais["lat"] <= 84.17)]
ais = ais[(ais["lon"] >= -16.1) & (ais["lon"] <= 32.88)]
ais = ais[(ais["sog"] >= 0) & (ais["sog"] <= 1022)]
ais = ais.dropna()  # removes missing values NaN
print("len(ais)", len(ais))
print("distinct mmsi", ais["mmsi"].nunique())
for m in (219027804, 111265120, 5322, 2190045, 6013464):
    print(m, (ais["mmsi"] == m).sum())
ais.to_parquet(f"{DATA}/ais_filtered.parquet")
