# Pandas part of the complete PyMEOS example of chapter 2, run on aisclean-2026-01-20.csv, the
# reports of the table AISClean of the AIS database of the book (export_aisclean.sh). Saves the
# frame for the next steps.
import os
from pathlib import Path

DATA = Path(os.environ.get('CH2_DATA', Path(__file__).resolve().parent / 'data'))  # input data, see README.md
import pandas as pd

ais = pd.read_csv(
    f"{DATA}/aisclean-2026-01-20.csv",
    usecols=["# Timestamp", "MMSI", "Latitude", "Longitude", "SOG"],
)
print("rows", len(ais))
ais.columns = ["t", "mmsi", "lat", "lon", "sog"]
ais["t"] = pd.to_datetime(ais["t"], format='%d/%m/%Y %H:%M:%S')
ais = ais.dropna()  # removes the reports without SOG
print("len(ais)", len(ais))
print("distinct mmsi", ais["mmsi"].nunique())
ais.to_parquet(f"{DATA}/ais_filtered.parquet")
