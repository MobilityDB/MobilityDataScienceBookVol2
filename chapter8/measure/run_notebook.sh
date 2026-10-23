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

# Execute a notebook of the chapter on the YARN cluster of docker-compose-nozeppelin.yml, with
# the driver in the container sedona_20, sampling every 30 seconds the memory available on the
# machine and the memory of each container while it runs.
#
#   bash run_notebook.sh <notebook> <run>
#
# <notebook> is the path of the notebook inside the container, for instance
# "/opt/notebooks/8.3 Create tables from scratch-flights-MobilitySpark.ipynb" once it is copied
# there with docker cp; the executed notebook is written beside it as out<run>.ipynb. The log of
# the execution, nb<run>.log, ending with the elapsed seconds, and the memory samples,
# mem<run>.log, are written into $OUT (default: out below the working directory).
# notebook_times.py reads the time of each cell from the executed notebook.
NB=${1:?notebook}
R=${2:?run}
OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
rm -f "$OUT/stop$R"
( while [ ! -f "$OUT/stop$R" ]; do
    echo "$(date +%T) $(free -m | awk '/Mem:/{print $7}') $(docker stats --no-stream --format '{{.Name}}={{.MemUsage}}' | tr -s ' ' | sed 's/ \/ [^ ]*//' | tr '\n' ' ')"
    sleep 30
  done ) > "$OUT/mem$R.log" 2>&1 &
start=$(date +%s)
docker exec -w "$(dirname "$NB")" sedona_20 jupyter nbconvert --to notebook --execute \
  --ExecutePreprocessor.timeout=-1 --output-dir "$(dirname "$NB")" --output "out$R.ipynb" "$NB" \
  > "$OUT/nb$R.log" 2>&1
rc=$?
echo "rc $rc elapsed $(( $(date +%s) - start )) s" >> "$OUT/nb$R.log"
touch "$OUT/stop$R"
wait
rm -f "$OUT/stop$R"
