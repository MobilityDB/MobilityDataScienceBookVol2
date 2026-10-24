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

# The environment of the book that tools/book_env/setup.sh builds, for a shell to source:
#
#   . tools/book_env/env.sh
#
# It activates BOOK_ENV/venv, the Python of every chapter but 9, and sets PYTHON and STREAMLIT to
# those of BOOK_ENV/venv-flink, which the scripts of chapter 9 run, MEOS_LIB and LD_LIBRARY_PATH
# to the directory of the libmeos.so that the chain of MobilityFlink built (ahead of any other
# libmeos.so of the system), the browsers of Playwright and the Maven repository.
BOOK_ENV=${BOOK_ENV:-/mnt/bookdb/env}
export BOOK_ENV
export PLAYWRIGHT_BROWSERS_PATH=$BOOK_ENV/ms-playwright
case " ${MAVEN_OPTS:-} " in
  *" -Dmaven.repo.local="*) ;;
  *) export MAVEN_OPTS="-Dmaven.repo.local=$BOOK_ENV/m2${MAVEN_OPTS:+ $MAVEN_OPTS}" ;;
esac
export MEOS_LIB=$BOOK_ENV/meos-chain/prefix/lib
case ":${LD_LIBRARY_PATH:-}:" in
  *":$MEOS_LIB:"*) ;;
  *) export LD_LIBRARY_PATH=$MEOS_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} ;;
esac
export PYTHON=$BOOK_ENV/venv-flink/bin/python
export STREAMLIT=$BOOK_ENV/venv-flink/bin/streamlit
if [ -f "$BOOK_ENV/venv/bin/activate" ]; then . "$BOOK_ENV/venv/bin/activate"; fi
