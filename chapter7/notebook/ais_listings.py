#!/usr/bin/env python3
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

# SPDX-License-Identifier: PostgreSQL
"""Print the SQL listings of chapter7.tex that read the AIS tables (AISInput, Ships), with the
line of each listing and the statement of the query it belongs to, in the order of the chapter.

Usage: python3 ais_listings.py <chapter7.tex> <out.json>
"""
import json
import re
import sys

src = open(sys.argv[1], encoding='utf-8').read()
out = []
for m in re.finditer(r'\\begin\{lstlisting\}(\[[^\]]*\])?\n(.*?)\\end\{lstlisting\}', src, re.S):
    body = m.group(2)
    if not re.search(r'\b(AISInput|ships|Ships)\b', body):
        continue
    line = src.count('\n', 0, m.start()) + 1
    before = src[max(0, m.start() - 1500):m.start()]
    q = re.findall(r'\\begin\{query\}.*?\\textit\{(.*?)\}', before, re.S)
    out.append({'line': line, 'query': q[-1].strip() if q else '', 'sql': body})
json.dump(out, open(sys.argv[2], 'w'), indent=1)
for o in out:
    first = o['sql'].strip().splitlines()[0][:70]
    print(o['line'], '|', o['query'][:60], '|', first)
