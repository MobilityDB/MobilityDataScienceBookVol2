"""The median and the 90th percentile of the error against the isolation (isolation.csv, recovery)
and against the horizon (horizon.csv, prediction), per model and speed class of the window (from
winspeed.csv: still below 0.5 knots, slow from 0.5 to 3 knots, moving at 3 knots or more, and all),
written to isolation_curve.csv and horizon_curve.csv, which fig_errors.py draws.

    python3 curves.py
"""
import csv, statistics as st
from collections import defaultdict
kn = {int(r['gapid']): float(r['kn'] or 0) for r in csv.DictReader(open('winspeed.csv'))}
def cls(g): k = kn[g]; return 'still' if k < 0.5 else ('slow' if k < 3 else 'moving')
for f, key in (('isolation.csv', 'steps'), ('horizon.csv', 'horizon')):
    d = defaultdict(list)
    for r in csv.DictReader(open(f)):
        g = int(r['gapid'])
        d[(r['model'], 'all', int(r[key]))].append(float(r['err']))
        d[(r['model'], cls(g), int(r[key]))].append(float(r['err']))
    out = open(f.replace('.csv', '_curve.csv'), 'w')
    out.write('model,class,x,n,median,p90\n')
    for (m, c, x), e in sorted(d.items()):
        e.sort()
        out.write(f"{m},{c},{x},{len(e)},{st.median(e):.2f},{e[int(.9 * len(e))]:.2f}\n")
    out.close()
