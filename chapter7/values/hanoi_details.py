"""Compute the values chapter 7 prints about the Hanoi queries (row counts, named examples, totals)
from the published BerlinMOD-Hanoi dataset in ${CH7_DB_DIR}/hanoi.duckdb, with the queries of
timing/specs/hanoi_mduck.json and the session settings of its setup.

Usage: python hanoi_details.py ../timing/specs/hanoi_mduck.json
"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'timing'))
import spec as specs  # noqa: E402

spec = specs.load(sys.argv[1])
con, _ = specs.connect(spec)
Q = {q['id']: q['duck'] for q in spec['queries']}
run = lambda sql: con.execute(sql).fetchall()

print('tz', run("SELECT min(startTimestamp(trip)), max(endTimestamp(trip)), count(*) FROM trips"))
ti = Q['q_tripint'].replace('ORDER BY intersectCount DESC\nLIMIT 1', 'ORDER BY intersectCount DESC')
rows = run(ti)
mx = rows[0][2]
print('tripint max', mx, 'trips', [(r[0], r[1]) for r in rows if r[2] == mx])
for r in [r for r in rows if r[2] == mx]:
    print('  ', r[0], r[1], run(f"""SELECT m.municipalityname, startTimestamp(atGeometry(trip, municipalitygeo)) s
      FROM trips t, municipalities m WHERE vehicleid={r[0]} AND tripid={r[1]}
      AND eintersects(trip, municipalitygeo) ORDER BY s"""))
print('per muni', run("""select municipalityname, COUNT(*) c from trips t, municipalities m
  where eintersects(t.trip, m.municipalitygeo) group by all order by c desc limit 8"""))
km = run(Q['q_totalkm'] + ' ORDER BY TotalKm')
print('totalkm', sum(float(r[1]) for r in km), km[:2], km[-2:])
e = run(Q['q24_edwithin'])
print('q24', len(e), [(r[0], r[1], r[3], r[4]) for r in e[:3]])
print('q26', len(run(Q['q26_lateral'])))
b = run(Q['q27_bins'])
print('q27', len(b), [(r[0], str(r[1]), r[2], r[3]) for r in b[:5]])
print('q28', len(run(Q['q28_tdwithin'])), len(run(Q['q28b_tdwithin'])))
print('q25 trips200', len(run(Q['q25_trips200'])))
g = run(Q['q_groups'])
print('groups', len(g), Counter(r[1] for r in g).most_common(3))
i = run(Q['q_instants'])
print('instants', len(i), 'points', len({r[2] for r in i}))
f = run(Q['q31_first'])
print('q31', len(f), 'points', len({r[1] for r in f}), [(r[0], r[1], str(r[3])) for r in f])
