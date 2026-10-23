#!/bin/bash
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

# Run the use case of chapter 11 from end to end in the AIS database of the book (the database
# named by PGDATABASE, PGHOST, ...), which holds the AIS day built by ais/build.sh and the tables
# of chapter 5 (Bathymetry, WaveHeight, NaturalAreas) and of load_context.sh. The code of the
# thesis is cloned into $DATA/FoundationModel at commit 2490c45, and run_model.py downloads the
# checkpoint of its main model, ablation_ffn_0710_best.pt of the Hugging Face model repository
# nhungoc1508/tfm, unless CHECKPOINT names a local copy. SAMPLE keeps that share of the gaps, in percent (100 by default), and EMBED=0 skips
# the embedding of the descriptions, which needs a Hugging Face token with access to EmbeddingGemma
# and is slow without a GPU; only the model that reconstructs from positions and times then runs.
#
#   SAMPLE=5 bash run_usecase.sh
#   EMBED=0 bash run_usecase.sh
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
PSQL="psql -X -v ON_ERROR_STOP=1"
export THESIS=$DATA/FoundationModel

if [ ! -d "$THESIS" ]; then
  git clone -q https://github.com/MobilityDB/FoundationModel "$THESIS"
fi
git -C "$THESIS" checkout -q 2490c45

$PSQL -v sample="${SAMPLE:-100}" -f "$HERE/01_sequences.sql"
$PSQL -f "$HERE/02_context.sql"
$PSQL -f "$HERE/03_descriptions.sql"
if [ "${EMBED:-1}" != 0 ]; then
  python3 "$HERE/embed.py"
else
  $PSQL -c "DROP TABLE IF EXISTS PointEmbedding CASCADE"
fi
$PSQL -f "$HERE/04_masks.sql"
python3 "$HERE/run_model.py"
$PSQL -f "$HERE/05_evaluate.sql"
$PSQL -f "$HERE/06_exact.sql"
$PSQL -f "$HERE/07_hermite.sql"
