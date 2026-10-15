#!/bin/bash
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
