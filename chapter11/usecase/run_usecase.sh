#!/bin/bash
# Run the use case of chapter 11 from end to end in the AIS database of the book (the database
# named by PGDATABASE, PGHOST, ...), which holds the AIS day built by ais/build.sh and the tables
# of chapter 5 (Bathymetry, WaveHeight, NaturalAreas) and of load_context.sh. The code of the
# thesis is cloned into $DATA/FoundationModel at commit 8fc3ca2, the commit of the published
# checkpoint. SAMPLE keeps that share of the gaps, in percent (100 by default), and EMBED=0 skips
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
git -C "$THESIS" checkout -q 8fc3ca2

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
