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

# Build the environment that runs the examples and draws the figures of the book, under BOOK_ENV
# (default: /mnt/bookdb/env). Each step builds what is missing and leaves the rest as it is, so the
# script may be run again at any time; REFRESH=1 rebuilds the chain of chapter 9 from the latest
# MobilityDB master.
#
#   bash tools/book_env/setup.sh
#   . tools/book_env/env.sh
#
# The packages are those of the `pip install` lines of the READMEs and scripts of this repository,
# with the version that any of them pins, and the requirements of chapter 11. PyFlink 2.1.3 needs
# a pyarrow older than 21 and the other chapters pin pyarrow 26.0.0, so the packages of chapter 9
# go into a venv of their own:
#
# - BOOK_ENV/venv, the packages of every chapter but 9, with the Python bindings of GDAL at the
#   version of the system library (gdal-config), which raquet-io requires;
# - BOOK_ENV/venv-flink, the packages of chapter 9, with the Kafka SQL connector of Flink in the
#   directory lib of PyFlink.
#
# Both use the Chromium of Playwright in BOOK_ENV/ms-playwright. The chain of chapter 9 clones
# MobilityFlink into BOOK_ENV/src/MobilityFlink, builds libmeos.so from MobilityDB master and
# the jar of JMEOS with tools/refresh-from-master.sh of MobilityFlink into BOOK_ENV/meos-chain,
# installs MobilityFlink in the Maven repository BOOK_ENV/m2, and builds the walk of chapter 9.
# BOOK_ENV/run/chapter9 is the directory from which the scripts of chapter 9 run: data links to
# BOOK_DATA (default: the directory data of this repository) and src to the directory of the
# libmeos.so of the chain.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
. "$REPO/tools/book_env/env.sh"
BOOK_DATA=${BOOK_DATA:-$REPO/data}
PY=${PYTHON312:-python3.12}

# The requirements: name[==version] of every `pip install` line, a name pinned anywhere keeping
# its pin, split by the chapter of the line
reqs() {
  git -C "$REPO" grep -oE 'pip install( [A-Za-z0-9_.-]+(==[0-9][0-9.]*)?)+' -- '*.md' '*.sh' |
  python3 -c '
import sys
want = sys.argv[1]
pins, names = {}, {}
for line in sys.stdin:
  path, cmd = line.rstrip("\n").split(":", 1)
  group = "flink" if path.startswith("chapter9/") else "book"
  toks = cmd.split()[2:]
  toks = [t for i, t in enumerate(toks) if not t.startswith("-") and not (i and toks[i - 1] == "-r")]
  for t in toks:
    n, _, v = t.partition("==")
    k = n.lower().replace("_", "-")
    if v: pins[k] = t
    names.setdefault(group, {}).setdefault(k, t)
print("\n".join(pins.get(k, t) for k, t in names.get(want, {}).items()))
' "$1"
}

venv() {
  local dir=$1; shift
  [ -x "$dir/bin/python" ] || "$PY" -m venv "$dir"
  "$dir/bin/pip" install -q --upgrade pip
  "$dir/bin/pip" install -q "$@"
}

echo "== venv: the packages of the book"
mapfile -t BOOK < <(reqs book)
venv "$BOOK_ENV/venv" "GDAL==$(gdal-config --version)" "${BOOK[@]}" \
  -r "$REPO/chapter11/figures/requirements.txt" -r "$REPO/chapter11/training/requirements.txt" \
  -r "$REPO/chapter11/usecase/requirements.txt"

echo "== venv-flink: the packages of chapter 9"
mapfile -t FLINK < <(reqs flink)
venv "$BOOK_ENV/venv-flink" "${FLINK[@]}"
PYLIB=$("$BOOK_ENV/venv-flink/bin/python" -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
KAFKA_JAR=flink-sql-connector-kafka-5.0.0-2.1.jar
[ -s "$PYLIB/$KAFKA_JAR" ] || curl -fsSL -o "$PYLIB/$KAFKA_JAR" \
  "https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/5.0.0-2.1/$KAFKA_JAR"

echo "== Playwright Chromium in $PLAYWRIGHT_BROWSERS_PATH"
"$BOOK_ENV/venv/bin/playwright" install chromium
"$BOOK_ENV/venv-flink/bin/playwright" install chromium

echo "== the chain of chapter 9: libmeos, JMEOS, MobilityFlink"
MF=$BOOK_ENV/src/MobilityFlink
CHAIN=$BOOK_ENV/meos-chain
if [ "${REFRESH:-0}" = 1 ] || [ ! -f "$CHAIN/.installed" ]; then
  rm -f "$CHAIN/.installed"
  if [ -d "$MF/.git" ]; then
    git -C "$MF" fetch -q https://github.com/MobilityDB/MobilityFlink main
    git -C "$MF" reset -q --hard FETCH_HEAD
  else
    mkdir -p "$BOOK_ENV/src"
    git clone -q https://github.com/MobilityDB/MobilityFlink "$MF"
  fi
  WORK_DIR=$CHAIN "$MF/tools/refresh-from-master.sh"
  (cd "$MF" && mvn -B -q -Dmeos.lib.dir="$MEOS_LIB" -DskipTests install)
  touch "$CHAIN/.installed"
fi

echo "== the walk of chapter 9"
(cd "$REPO/chapter9/Flink_Examples/flights_stream/walk" && mvn -B -q package)

mkdir -p "$BOOK_ENV/run/chapter9"
ln -sfn "$BOOK_DATA" "$BOOK_ENV/run/chapter9/data"
ln -sfn "$MEOS_LIB" "$BOOK_ENV/run/chapter9/src"
echo "== done: . $REPO/tools/book_env/env.sh"
