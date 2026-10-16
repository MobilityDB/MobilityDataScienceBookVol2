"""Time the two queries of chapter 7 that sample ships (TABLESAMPLE RESERVOIR), as the chapter
reports them: in each engine, over the same ships, for samples of 300 and 600 ships, in three
rounds that alternate the engines.

Usage: python bench_sample.py specs/ais_sample.json <result.json>
The DuckDB query is the listing as printed, with the sample size substituted. The MobilityDB
query reads the same ships, those of the sample read back with the same TABLESAMPLE clause, as
`MMSI IN (...)` in place of the clause. Each engine runs its query twice in a row and the second
(warm) time is kept, as bench.py does. No routine of the companion draws one sample for two
engines; the nearest is #psql of chapter11/figures/export_hermite.py, which runs a statement in
one engine. The two helpers below are shared with bench_close_forms.py.
"""
import json
import sys
import time

import spec as specs

CLAUSE = 'TABLESAMPLE RESERVOIR (300 ROWS) REPEATABLE (1)'
PERIOD = "tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)'"


def sampled(duck, n):
    return [r[0] for r in duck.execute(
        f'SELECT MMSI FROM Ships TABLESAMPLE RESERVOIR ({n} ROWS) REPEATABLE (1)').fetchall()]


def pg_form(q, mmsis):
    p = q.replace(f'Ships s {CLAUSE}', 'Ships s').replace(
        'WHERE atTime(s.Trip, t.Period) IS NOT NULL',
        f"WHERE s.MMSI IN ({','.join(map(str, mmsis))}) AND atTime(s.Trip, t.Period) IS NOT NULL")
    assert p != q
    return p


if __name__ == '__main__':
    spec = specs.load(sys.argv[1])
    out = sys.argv[2]
    duck, pg = specs.connect(spec)
    result = {'runs': []}
    for rnd in (1, 2, 3):
        for q in spec['queries']:
            assert CLAUSE in q['duck'], q['id']
            for n in (300, 600):
                dq = q['duck'].replace('(300 ROWS)', f'({n} ROWS)')
                pq = pg_form(q['duck'], sampled(duck, n))
                for _ in range(2):
                    t0 = time.perf_counter()
                    nd = len(duck.execute(dq).fetchall())
                    td = time.perf_counter() - t0
                for _ in range(2):
                    t0 = time.perf_counter()
                    np_ = len(pg.execute(pq).fetchall())
                    tp = time.perf_counter() - t0
                observed = duck.execute(
                    f'SELECT count(*) FROM Ships s TABLESAMPLE RESERVOIR ({n} ROWS) REPEATABLE (1) '
                    f'WHERE atTime(s.Trip, {PERIOD}) IS NOT NULL').fetchone()[0]
                run = {'round': rnd, 'load': specs.load_average(), 'query': q['id'], 'ships': n,
                       'observed': observed, 'duck_s': td, 'pg_s': tp, 'ratio': tp / td,
                       'duck_rows': nd, 'pg_rows': np_}
                result['runs'].append(run)
                print(run, flush=True)
                json.dump(result, open(out, 'w'), indent=1)
