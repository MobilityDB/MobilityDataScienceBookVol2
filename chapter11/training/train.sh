#!/usr/bin/env bash
# Retrain the trajectory foundation model of chapter 11 with the configuration
# of the book (Table 11.5), using the training program of the thesis at commit
# 72d9fec of github.com/MobilityDB/FoundationModel and the data downloaded by
# fetch_data.sh into $DATA (default: data/).
set -euo pipefail

DATA="${DATA:-data}"
SEED="${SEED:-1508}"
THESIS="${THESIS:-FoundationModel}"
COMMIT=72d9fecae5211b67661fba0e8d286b9839b8b125

if [ ! -d "$THESIS" ]; then
  git clone https://github.com/MobilityDB/FoundationModel "$THESIS"
fi
git -C "$THESIS" checkout --quiet "$COMMIT"

python "$THESIS/models/train.py" \
  --urban-train "$DATA/urban/train/parquet" \
  --urban-val "$DATA/urban/val/parquet" \
  --urban-sem-npy "$DATA/urban/train/npy" \
  --urban-val-sem-npy "$DATA/urban/val/npy" \
  --maritime-train "$DATA/maritime/train/parquet" \
  --maritime-val "$DATA/maritime/val/parquet" \
  --maritime-sem-npy "$DATA/maritime/train/npy" \
  --maritime-val-sem-npy "$DATA/maritime/val/npy" \
  --no-moe \
  --batch-size 1536 \
  --lr 1.4e-3 \
  --max-len 256 \
  --stage1-epochs 0 \
  --stage2-epochs 50 \
  --seed "$SEED" \
  --checkpoint-dir checkpoints \
  --run-name main \
  "$@"
