#!/usr/bin/env bash
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
