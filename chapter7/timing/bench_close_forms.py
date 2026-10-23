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

"""Time three forms of the condition of chapter 7's query que:close300 in MobilityDuck and in
MobilityDB, over the same sampled ships (300 and 600), in three rounds that alternate the
engines, keeping the second (warm) of two runs, as bench_sample.py does.

  and   eDwithin(...) AND startValue(atMin(...)) < 300
  case  CASE WHEN eDwithin(...) THEN startValue(atMin(...)) < 300 END   (the form printed)
  box   s1.Trip && expandSpace(s2.Trip::stbox, 300) AND eDwithin(...) AND startValue(...) < 300

Usage: python bench_close_forms.py specs/ais_sample.json <result.json>
"""
import json
import sys
import time

import spec as specs
from bench_sample import pg_form, sampled

spec = specs.load(sys.argv[1])
out = sys.argv[2]
duck, pg = specs.connect(spec)
(base,) = [q['duck'] for q in spec['queries'] if q['id'] == 'close']
cond_case = ('CASE WHEN eDwithin(s1.Trip, s2.Trip, 300)\n'
             '  THEN startValue(atMin(s1.Trip <-> s2.Trip)) < 300 END')
assert cond_case in base
cond_and = 'eDwithin(s1.Trip, s2.Trip, 300) AND startValue(atMin(s1.Trip <-> s2.Trip)) < 300'
forms = {'and': base.replace(cond_case, cond_and),
         'case': base,
         'box': base.replace(cond_case, 's1.Trip && expandSpace(s2.Trip::stbox, 300) AND ' + cond_and)}

result = {'runs': []}
for rnd in (1, 2, 3):
    for n in (300, 600):
        mmsis = sampled(duck, n)
        for name, q in forms.items():
            dq = q.replace('(300 ROWS)', f'({n} ROWS)')
            pq = pg_form(q, mmsis)
            for _ in range(2):
                t0 = time.perf_counter()
                drows = duck.execute(dq).fetchall()
                td = time.perf_counter() - t0
            for _ in range(2):
                t0 = time.perf_counter()
                prows = pg.execute(pq).fetchall()
                tp = time.perf_counter() - t0
            run = {'round': rnd, 'ships': n, 'form': name, 'duck_s': td, 'pg_s': tp, 'ratio': tp / td,
                   'duck_rows': len(drows), 'pg_rows': len(prows), 'load': specs.load_average()}
            result['runs'].append(run)
            print(f"round {rnd} {n} {name:4}: duck {td:7.2f}s pg {tp:7.2f}s ratio {tp / td:5.2f} "
                  f"rows {len(drows)}/{len(prows)} load {run['load']}", flush=True)
            json.dump(result, open(out, 'w'), indent=1)
