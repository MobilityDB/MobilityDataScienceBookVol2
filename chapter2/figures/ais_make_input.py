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
