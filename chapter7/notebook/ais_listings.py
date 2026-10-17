#!/usr/bin/env python3
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
