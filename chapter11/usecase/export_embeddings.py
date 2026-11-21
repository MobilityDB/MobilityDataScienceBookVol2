"""Write the table PointEmbedding(GapId, PointIdx, Emb) to the files of embeddings/ that
load_embeddings.py reads, so that the use case runs without the encoder.

Each file embeddings/point_embedding_<k>.npz holds, for its share of the rows in the order of
(GapId, PointIdx), the arrays gapid and pointidx, desc_md5, the MD5 of the description of
PointDescriptor that the row embeds (16 bytes), and emb, the 256 values of the embedding as the
upper 16 bits of their single-precision representation. EmbeddingGemma computes in bfloat16, so
these bits are the whole of every value, and the files give back the embeddings exactly. Each file
stays under 50 MB, the size above which GitHub warns.

    python export_embeddings.py [directory]

The connection is given by the PostgreSQL environment variables (PGDATABASE, PGHOST, ...).
"""
import hashlib
import sys
from pathlib import Path

import numpy as np
import psycopg

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent / 'embeddings')
ROWS_PER_FILE = 90000

with psycopg.connect() as conn:
    rows = conn.execute(
        'SELECT e.GapId, e.PointIdx, d.Description, e.Emb '
        'FROM PointEmbedding e JOIN PointDescriptor d USING (GapId, PointIdx) '
        'ORDER BY e.GapId, e.PointIdx').fetchall()
    total = conn.execute('SELECT count(*) FROM PointEmbedding').fetchone()[0]
if len(rows) != total:
    sys.exit(f'{total - len(rows)} embeddings have no description in PointDescriptor')

emb = np.asarray([r[3] for r in rows], dtype=np.float32)
bits = emb.view(np.uint32)
if np.any(bits & 0xFFFF):
    sys.exit('the embeddings are not bfloat16 values; they cannot be written in 16 bits')
OUT.mkdir(parents=True, exist_ok=True)
for old in OUT.glob('point_embedding_*.npz'):
    old.unlink()
for k, lo in enumerate(range(0, len(rows), ROWS_PER_FILE)):
    part = rows[lo:lo + ROWS_PER_FILE]
    np.savez_compressed(
        OUT / f'point_embedding_{k}.npz',
        gapid=np.asarray([r[0] for r in part], dtype=np.int64),
        pointidx=np.asarray([r[1] for r in part], dtype=np.int64),
        desc_md5=np.frombuffer(b''.join(hashlib.md5(r[2].encode()).digest() for r in part),
                               dtype=np.uint8).reshape(-1, 16),
        emb=(bits[lo:lo + ROWS_PER_FILE] >> 16).astype(np.uint16))
print(f'{len(rows)} embeddings of {emb.shape[1]} dimensions written to {OUT}')
