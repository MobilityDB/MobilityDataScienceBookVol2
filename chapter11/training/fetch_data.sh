#!/usr/bin/env bash
# Download the encoded corpus of the trajectory foundation model of chapter 11
# from Kaggle into $DATA (default: data/), and set the held-out Cabspotting
# files apart from the training, validation, and test directories.
#
# Requires the Kaggle command-line client with an API token in
# ~/.kaggle/kaggle.json. The three datasets take about 67 GB.
set -euo pipefail

DATA="${DATA:-data}"
mkdir -p "$DATA"

for domain in urban maritime heldout; do
  if [ -d "$DATA/$domain" ]; then
    echo "$DATA/$domain exists, skipping its download"
    continue
  fi
  kaggle datasets download -d "nhungoc1508/trajectory-foundation-model-$domain" \
    -p "$DATA/$domain" --unzip
done

# Cabspotting is part of the held-out set: keep it out of the urban splits
mkdir -p "$DATA/heldout/urban-splits"
find "$DATA/urban" -name 'cabspotting_*' -exec mv -t "$DATA/heldout/urban-splits" {} +

echo "Urban parquet files used for training:"
ls "$DATA/urban/train/parquet"
echo "Maritime days used for training: $(ls "$DATA/maritime/train/parquet" | wc -l)"
