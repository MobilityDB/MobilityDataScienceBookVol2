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

# Draw every figure of the chapter drawn from data into $OUT (default: out/
# below the working directory), from the AIS database built by ais_poses.sql and
# load_turbines.sql and the nuScenes database built by load_nuscenes.sql: each export script writes the
# layers and the spec of its map figures, and render.sh draws them with QGIS.
# The databases are named by the PostgreSQL environment variables and by AIS_DB
# and NUSCENES_DB (see figlib.py). With the default QGIS of Windows called from
# WSL, $OUT must be on a Windows drive (/mnt/c/...).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
export OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
python3 "$HERE/export_ais.py"
python3 "$HERE/export_nuscenes.py"
for s in ais nuscenes; do
  bash "$HERE/render.sh" "spec_$s.json"
done
