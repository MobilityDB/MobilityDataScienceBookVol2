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

"""Complete PyMEOS example of chapter 2 (CSV -> TGeogPointSeq/TFloatSeq -> the table pymeos.Ships
of the AIS database of the book); pymeos_ais2_plot.py reads one ship back and plots it.

The statements are those printed in the chapter. To bound memory, the instant construction, the
groupby aggregation and the INSERT run over batches of MMSIs; each MMSI lies in one batch, so the
per-ship results are those of the single-pass code.
"""
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
import pandas as pd
from pymeos import *
from pymeos.db.psycopg import MobilityDB

pymeos_initialize()
ais = pd.read_parquet(f"{DATA}/ais_filtered.parquet")
print("len(ais)", len(ais))

connection = MobilityDB.connect(host=os.environ.get("PGHOST", "localhost"),
                                port=int(os.environ.get("PGPORT", 5433)),
                                dbname=os.environ.get("PGDATABASE", "ais"),
                                user=os.environ.get("PGUSER", "postgres"),
                                password=os.environ.get("PGPASSWORD", "postgres"))
cursor = connection.cursor()
cursor.execute("CREATE SCHEMA IF NOT EXISTS pymeos;")
cursor.execute("DROP TABLE IF EXISTS pymeos.Ships;")
cursor.execute(
    "CREATE TABLE pymeos.Ships"
    "(MMSI integer, Trajectory public.tgeogpoint, SOG public.tfloat);")
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
        comparison["PyMEOS #points"] / comparison["original #points"] * 100)
    comparisons.append(comparison)
    query = "INSERT INTO pymeos.Ships(MMSI, Trajectory, SOG) VALUES"
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
cursor.execute("SELECT COUNT(*) FROM pymeos.Ships;")
print("COUNT", cursor.fetchone()[0])
cursor.close()
pymeos_finalize()
