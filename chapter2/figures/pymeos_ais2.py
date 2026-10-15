"""Complete PyMEOS example of chapter 2 (CSV -> TGeogPointSeq/TFloatSeq -> MobilityDB -> plot).

The statements are those printed in the chapter. To bound memory, the instant construction, the
groupby aggregation and the INSERT run over batches of MMSIs; each MMSI lies in one batch, so the
per-ship results are those of the single-pass code.
"""
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from pymeos import *
from pymeos.db.psycopg import MobilityDB

pymeos_initialize()
ais = pd.read_parquet(f"{DATA}/ais_filtered.parquet")
print("len(ais)", len(ais))

connection = MobilityDB.connect(host=os.environ.get("PGHOST", "localhost"),
                                port=int(os.environ.get("PGPORT", 5433)), dbname="vessels",
                                user=os.environ.get("PGUSER", "postgres"),
                                password=os.environ.get("PGPASSWORD", "postgres"))
cursor = connection.cursor()
cursor.execute("DROP TABLE IF EXISTS public.ships;")
cursor.execute(
    "CREATE TABLE public.ships"
    "(MMSI integer, trajectory public.tgeogpoint, SOG public.tfloat);")
connection.commit()

mmsis = sorted(ais["mmsi"].unique())
B = 300
comparisons = []
for k in range(0, len(mmsis), B):
    part = ais[ais["mmsi"].isin(mmsis[k:k + B])].copy()
    part["instant"] = part.apply(
        lambda row: TGeogPointInst(point=(row["lon"], row["lat"]), timestamp=row["t"]), axis=1)
    part["sog"] = part.apply(
        lambda row: TFloatInst(value=row["sog"], timestamp=row["t"]), axis=1)
    part.drop(["lat", "lon"], axis=1, inplace=True)
    trajectories = (
        part.groupby("mmsi")
        .aggregate(
            {
                "instant": lambda x: TGeogPointSeq.from_instants(x, upper_inc=True),
                "sog": lambda x: TFloatSeq.from_instants(x, upper_inc=True),
            }
        ).rename({"instant": "trajectory"}, axis=1)
    )
    trajectories["distance"] = trajectories["trajectory"].apply(lambda t: t.length())
    comparison = pd.concat(
        [
            part.groupby("mmsi")["t"].count().rename("original #points"),
            trajectories["trajectory"].
            apply(lambda t: t.num_instants()).rename("PyMEOS #points"),
        ],
        axis=1,
    )
    comparison["Points kept (%)"] = (
        comparison["PyMEOS #points"] / comparison["original #points"] * 100
    )
    comparisons.append(comparison)
    query = "INSERT INTO public.ships(MMSI, trajectory, SOG) VALUES"
    for mmsi, row in trajectories.iterrows():
        query += f"\n({mmsi}, '{row.trajectory}', '{row.sog}'),"
    query = query[:-1] + ";"
    cursor.execute(query)
    connection.commit()
    print(k, flush=True)

comparison = pd.concat(comparisons)
comparison.to_csv(f"{DATA}/comparison.csv")
print(comparison.head(3).to_string())
print("total original", comparison["original #points"].sum(),
      "total pymeos", comparison["PyMEOS #points"].sum())
cursor.execute("SELECT COUNT(*) FROM ships;")
print("COUNT", cursor.fetchone()[0])

cursor.execute("SELECT * FROM public.ships WHERE MMSI = 111219517;")
mmsi, trajectory, sog = cursor.fetchone()
cursor.close()
print(type(trajectory), trajectory.num_instants(), sog.num_instants(),
      trajectory.start_timestamp(), trajectory.end_timestamp(), sog.min_value(), sog.max_value())

fig, axes = plt.subplots(1, 2, figsize=(20, 10))
trajectory.plot(axes=axes[0])
sog.plot(axes=axes[1])
plt.suptitle(f"Ship {mmsi}")
fig.savefig(f"{OUT}/pymeosais2_full.png", dpi=72)
for i, ax in enumerate(axes):
    ext = ax.get_tightbbox(fig.canvas.get_renderer()).transformed(fig.dpi_scale_trans.inverted())
    fig.savefig(f"{OUT}/pymeosais2_{'ab'[i]}.png",
                bbox_inches=ext.expanded(1.02, 1.02), dpi=72)
pymeos_finalize()
