"""Time chapter 7's query over the Parquet file against the same query over the CSV file, in
DuckDB: three alternating rounds, the second (warm) of two runs kept, as bench.py times the
engines.

Usage: python bench_parquet.py
The files are ${AIS_DIR}/aisdk-2026-01-20.csv and ${AIS_DIR}/ais.parquet, the latter written by
the listing of the chapter that values/section_duckdb.sql runs.
"""
import os
import time

import duckdb

import spec as specs

d = os.environ['AIS_DIR']
con = duckdb.connect()
q = "SELECT MMSI, COUNT(*) FROM '{}' GROUP BY ALL"
files = {'csv': f'{d}/aisdk-2026-01-20.csv', 'parquet': f'{d}/ais.parquet'}
for r in range(3):
    t = {}
    for kind, f in files.items():
        for _ in range(2):
            t0 = time.perf_counter()
            n = len(con.execute(q.format(f)).fetchall())
            t[kind] = time.perf_counter() - t0
    print(f"round {r + 1}: csv {t['csv']:.3f}s parquet {t['parquet']:.4f}s ratio {t['csv'] / t['parquet']:.1f} "
          f"({n} groups, load {specs.load_average()})", flush=True)
