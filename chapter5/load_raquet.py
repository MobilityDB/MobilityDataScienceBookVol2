"""Section 8: load a RaQuet file produced by the official raquet-io converter
into a PostgreSQL table of MobilityDB raquet tiles.

Usage: python3 load_raquet.py <file.parquet> <table> <connection string>

Each row of the file is a tile: the QUADBIN cell in the column block, and the
gzip-compressed pixels of each band. The first band is loaded, with the tile
dimensions, pixel type and nodata value stated in the metadata row (block 0).
"""
import gzip
import json
import sys

import psycopg2
import pyarrow.parquet as pq

PIXTYPES = {"uint8": "UINT8", "int16": "INT16", "int32": "INT32",
            "float32": "FLOAT32", "float64": "FLOAT64"}


def main(path, table, dsn):
    pf = pq.ParquetFile(path)
    meta = None
    for batch in pf.iter_batches(columns=["block", "metadata"], batch_size=64):
        for block, md in zip(batch.column("block").to_pylist(),
                             batch.column("metadata").to_pylist()):
            if block == 0 and md:
                meta = json.loads(md)
    if meta is None:
        raise SystemExit("no metadata row")
    band = meta["bands"][0]
    width, height = meta["tiling"]["block_width"], meta["tiling"]["block_height"]
    pixtype = PIXTYPES[band["type"]]
    nodata = band.get("nodata")
    compressed = meta.get("compression") == "gzip"
    conn = psycopg2.connect(dsn)
    cur = conn.cursor()
    cur.execute(f"DROP TABLE IF EXISTS {table}")
    cur.execute(f"CREATE TABLE {table}(Tile raquet)")
    count = 0
    for batch in pf.iter_batches(columns=["block", band["name"]], batch_size=64):
        rows = []
        for block, pixels in zip(batch.column("block").to_pylist(),
                                 batch.column(band["name"]).to_pylist()):
            if block == 0 or pixels is None:
                continue
            data = gzip.decompress(pixels) if compressed else pixels
            rows.append((psycopg2.Binary(data), width, height, block, pixtype,
                         None if nodata is None else float(nodata)))
        cur.executemany(
            f"INSERT INTO {table} VALUES (raquet(%s, %s, %s, quadbin(%s::bigint), %s, %s))",
            rows)
        count += len(rows)
    cur.execute(f"CREATE INDEX {table}_Quadbin_Idx ON {table} (quadbin(Tile))")
    cur.execute(f"ANALYZE {table}")
    conn.commit()
    print(count, "tiles loaded into", table)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
