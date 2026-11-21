"""Load the table PointEmbedding(GapId, PointIdx, Emb) from the files of embeddings/, the
embeddings of the descriptions of the book computed by embed.py with EmbeddingGemma in bfloat16 on
a GPU, so that the use case runs without the encoder, a Hugging Face account, or a GPU.

Each file holds the keys of its rows, the MD5 of the description each row embeds, and the 256
values of each embedding as the upper 16 bits of their single-precision representation, which are
the whole of a bfloat16 value (export_embeddings.py). A row is loaded only when its gap and position
are in PointDescriptor with the same description; the script stops if a description of
PointDescriptor has no embedding or embeds another text, since the descriptions of the database then
differ from those of the book and embed.py must compute their embeddings.

    python load_embeddings.py [directory]

The connection is given by the PostgreSQL environment variables (PGDATABASE, PGHOST, ...).
"""
import hashlib
import sys
from pathlib import Path

import numpy as np
import psycopg

DIR = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent / 'embeddings')

with psycopg.connect() as conn:
    wanted = {(g, i): hashlib.md5(d.encode()).digest() for g, i, d in conn.execute(
        'SELECT GapId, PointIdx, Description FROM PointDescriptor').fetchall()}
    conn.execute('DROP TABLE IF EXISTS PointEmbedding CASCADE')
    conn.execute('CREATE TABLE PointEmbedding(GapId bigint, PointIdx bigint, Emb real[], '
                 'PRIMARY KEY (GapId, PointIdx))')
    loaded = 0
    other = 0
    with conn.cursor().copy('COPY PointEmbedding FROM STDIN') as copy:
        for f in sorted(DIR.glob('point_embedding_*.npz'), key=lambda p: int(p.stem.split('_')[-1])):
            z = np.load(f)
            emb = (z['emb'].astype(np.uint32) << 16).view(np.float32)
            for g, i, md5, e in zip(z['gapid'].tolist(), z['pointidx'].tolist(), z['desc_md5'], emb):
                want = wanted.get((g, i))
                if want is None:
                    continue
                if want != md5.tobytes():
                    other += 1
                    continue
                copy.write_row((g, i, e.tolist()))
                loaded += 1
    missing = len(wanted) - loaded
    if missing:
        conn.rollback()
        sys.exit(f'{missing} descriptions of PointDescriptor have no embedding in {DIR} '
                 f'({other} of them describe another text): run embed.py')
print(f'{loaded} embeddings loaded from {DIR}')
