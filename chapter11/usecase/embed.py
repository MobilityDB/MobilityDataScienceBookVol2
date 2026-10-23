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

"""Embed the descriptions of PointDescriptor into the table PointEmbedding(GapId, PointIdx, Emb).

The descriptions are encoded by the encoder of the thesis (enrichment-pipeline/shared/encoder.py,
class SemanticEncoder) with the settings with which the corpus was encoded: EmbeddingGemma
(google/embeddinggemma-300m) with outputs truncated to 256 dimensions and normalized, in bfloat16
on a GPU. The embeddings are written with the COPY protocol of psycopg.

    THESIS=<clone of MobilityDB/FoundationModel> python embed.py

The connection is given by the PostgreSQL environment variables (PGDATABASE, PGHOST, ...).
EmbeddingGemma is a gated model: its license must be accepted on its Hugging Face page and a
token stored with `hf auth login` before the first run.
"""
import os
import sys
from pathlib import Path

import psycopg

sys.path.insert(0, str(Path(os.environ['THESIS']) / 'enrichment-pipeline' / 'shared'))
from encoder import SemanticEncoder  # noqa: E402

with psycopg.connect() as conn:
    rows = conn.execute(
        'SELECT GapId, PointIdx, Description FROM PointDescriptor ORDER BY GapId, PointIdx'
    ).fetchall()
    encoder = SemanticEncoder(model_name='google/embeddinggemma-300m', truncate_dim=256,
                              batch_size=256, trust_remote_code=True)
    embs = encoder.encode([r[2] for r in rows], show_progress=True)
    conn.execute('DROP TABLE IF EXISTS PointEmbedding CASCADE')
    conn.execute('CREATE TABLE PointEmbedding(GapId bigint, PointIdx bigint, Emb real[], '
                 'PRIMARY KEY (GapId, PointIdx))')
    with conn.cursor().copy('COPY PointEmbedding FROM STDIN') as copy:
        for (gap, idx, _), emb in zip(rows, embs):
            copy.write_row((gap, idx, emb.astype(float).tolist()))
    print(f'{len(rows)} descriptions embedded in {embs.shape[1]} dimensions')
