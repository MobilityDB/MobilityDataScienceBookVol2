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

# Download the raw files of the two multibeam survey lines of the use case on
# seabed surveys into $DATA/soundings (default: data/soundings below the
# working directory): the lines of May 14 and October 22, 2019 off Rostock that
# cross each other, from the raw data of Schulze and Feldens (2022) at PANGAEA
# (CC-BY-4.0), one file of 400 kHz per survey in the vendor format s7k (Reson
# 7K), with no account needed. PANGAEA may answer 503 while it takes a file out
# of its archive, so curl retries such a file 40 times, as fetch() of
# ../../chapter5/fetch_data.sh does with its retries.
#
#   bash fetch_soundings.sh
set -e
DATA=${DATA:-$PWD/data}
mkdir -p "$DATA/soundings"
P=https://download.pangaea.de/dataset
for f in 945743/files/20190514_124053_kh1905_400khz.s7k \
    945782/files/20191022_085450_kh1910_400khz.s7k; do
  out=$DATA/soundings/${f##*/}
  if [ -s "$out" ]; then echo "present: $out"; else
    echo "fetching: $out"
    curl -fL --retry 40 -o "$out.part" "$P/$f" && mv "$out.part" "$out"
  fi
done
