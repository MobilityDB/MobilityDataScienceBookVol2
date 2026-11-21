#!/bin/bash
# Run the use case of chapter 11 from end to end in the AIS database of the book (the database
# named by PGDATABASE, PGHOST, ...), which holds the AIS day built by ais/build.sh and the tables
# of chapter 5 (Bathymetry, WaveHeight, NaturalAreas) and of load_context.sh. The code of the
# thesis is cloned into $DATA/FoundationModel at commit 2490c45, and run_model.py downloads the
# checkpoint of its main model, ablation_ffn_0710_best.pt of the Hugging Face model repository
# nhungoc1508/tfm, unless CHECKPOINT names a local copy. SAMPLE keeps that share of the gaps, in
# percent (100 by default). The embeddings of the descriptions are those of the book, loaded from
# embeddings/ by load_embeddings.py; EMBED=1 computes them again with embed.py, which needs a
# Hugging Face token with access to EmbeddingGemma and is slow without a GPU, and EMBED=0 skips
# them, so that only the model that reconstructs from positions and times runs.
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
case ${EMBED:-load} in
  load) python3 "$HERE/load_embeddings.py" ;;
  0) $PSQL -c "DROP TABLE IF EXISTS PointEmbedding CASCADE" ;;
  *) python3 "$HERE/embed.py" ;;
esac
$PSQL -f "$HERE/04_masks.sql"
python3 "$HERE/run_model.py"
$PSQL -f "$HERE/05_evaluate.sql"
$PSQL -f "$HERE/06_exact.sql"
$PSQL -f "$HERE/07_hermite.sql"
