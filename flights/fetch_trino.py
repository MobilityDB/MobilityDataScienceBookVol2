#!/usr/bin/env python3
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
"""Rebuild the flights data of the book from the historical database of the OpenSky Network.

The day of the book, Sunday, March 1, 2026, is read from the table state_vectors_data4 of the
Trino interface of OpenSky, one hour at a time, into the files that fetch_data.sh downloads from
the public samples of OpenSky when they are served: one Parquet file per hour in
$DATA/flights/parquet/hour=<Unix time of the hour>/, with the 16 columns that build.sh and the
notebooks of chapter 8 read. The countries of Natural Earth come from fetch_data.sh, which
downloads them whatever the samples hold.

The interface needs an account of the OpenSky Network, which its terms grant for non-profit
research and education, and the Python package pyopensky (pip install pyopensky), which reads the
account from its settings file, ~/.config/pyopensky/settings.conf on Linux:

    [default]
    username = <your OpenSky user name>
    password = <your OpenSky password>

    python3 fetch_trino.py

An hour is written under a temporary name and renamed once complete, so a run that stops resumes
at the first hour missing. The terms of OpenSky forbid passing the data on: each reader fetches
it with their own account, and a publication using it cites the OpenSky Network as its terms
state.
"""
import os
import sys
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
from pyopensky.trino import Trino

DAY = 1772323200  # 2026-03-01 00:00:00 UTC, the day of the book
HOURS = [DAY + 3600 * h for h in range(24)]
COLUMNS = ["time", "icao24", "lat", "lon", "velocity", "heading", "vertrate", "callsign",
           "onground", "alert", "spi", "squawk", "baroaltitude", "geoaltitude",
           "lastposupdate", "lastcontact"]
SCHEMA = pa.schema([
    ("time", pa.int64()), ("icao24", pa.string()), ("lat", pa.float64()),
    ("lon", pa.float64()), ("velocity", pa.float64()), ("heading", pa.float64()),
    ("vertrate", pa.float64()), ("callsign", pa.string()), ("onground", pa.bool_()),
    ("alert", pa.bool_()), ("spi", pa.bool_()), ("squawk", pa.string()),
    ("baroaltitude", pa.float64()), ("geoaltitude", pa.float64()),
    ("lastposupdate", pa.float64()), ("lastcontact", pa.float64())])
BATCH = 200_000

out = Path(os.environ.get("DATA", Path.cwd() / "data")) / "flights" / "parquet"
trino = Trino()
if trino.token() is None:
    sys.exit("fetch_trino.py: no OpenSky account in the settings of pyopensky "
             "(~/.config/pyopensky/settings.conf): see the comment at the top of this file")
total = 0
for hour in HOURS:
    target = out / f"hour={hour}" / "state_vectors.parquet"
    if target.exists():
        print(f"present: {target}")
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_suffix(".parquet.part")
    cur = trino.engine().raw_connection().cursor()
    cur.execute(f"SELECT {', '.join(COLUMNS)} FROM state_vectors_data4 WHERE hour = {hour}")
    rows = 0
    with pq.ParquetWriter(part, SCHEMA, compression="zstd") as writer:
        while batch := cur.fetchmany(BATCH):
            writer.write_table(pa.Table.from_pylist(
                [dict(zip(COLUMNS, row)) for row in batch], schema=SCHEMA))
            rows += len(batch)
    part.rename(target)
    total += rows
    print(f"hour={hour}: {rows} state vectors")
print(f"{total} state vectors written; the day holds 695,706,186 (README.md)")
