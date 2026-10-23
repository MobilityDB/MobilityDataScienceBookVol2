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

"""Time the queries of chapter 7 in DuckDB and in PostgreSQL, as the chapter reports them.

Usage: python bench.py specs/<spec>.json <result.json>
Each round runs every query in DuckDB, then in PostgreSQL, twice in a row each, and keeps the
second (warm) time; the rounds alternate the engines, so that the ratio of a round carries the
load of the machine at that moment. The chapter reports the ratio PostgreSQL / DuckDB, as the
range over the rounds. The result holds, per query, the times of every round, the ratio of every
round, and the rows each engine returned.
"""
import json
import sys
import time

import spec as specs

spec = specs.load(sys.argv[1])
out = sys.argv[2]
duck, pg = specs.connect(spec)

result = {'load': [], 'queries': {}}
for q in spec['queries']:
    result['queries'][q['id']] = {'duck_s': [], 'pg_s': [], 'ratio': [], 'duck_rows': None, 'pg_rows': None}
for r in range(spec.get('rounds', 3)):
    result['load'].append(specs.load_average())
    for q in spec['queries']:
        res = result['queries'][q['id']]
        for _ in range(2):
            t0 = time.perf_counter()
            nd = len(duck.execute(q['duck']).fetchall())
            td = time.perf_counter() - t0
        for _ in range(2):
            t0 = time.perf_counter()
            cur = pg.execute(q['pg'])
            np_ = len(cur.fetchall()) if cur.description else 0
            tp = time.perf_counter() - t0
        res['duck_s'].append(td)
        res['pg_s'].append(tp)
        res['ratio'].append(tp / td)
        res['duck_rows'], res['pg_rows'] = nd, np_
        print(f"round {r + 1} {q['id']}: duck {td:.4f}s ({nd} rows)  pg {tp:.3f}s ({np_} rows)  "
              f"ratio {tp / td:.1f}", flush=True)
        json.dump(result, open(out, 'w'), indent=1)
for qid, res in result['queries'].items():
    print(f"{qid}: ratio {min(res['ratio']):.1f}-{max(res['ratio']):.1f}  "
          f"rows duck {res['duck_rows']} pg {res['pg_rows']}")
