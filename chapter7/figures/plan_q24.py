"""Write the plan of chapter 7's Query 24 (eDwithin over the Hanoi trips), as EXPLAIN ANALYZE
prints it, with the database and the session settings of timing/specs/hanoi_mduck.json.

Usage: python plan_q24.py ../timing/specs/hanoi_mduck.json <plan.txt>
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'timing'))
import spec as specs  # noqa: E402

spec = specs.load(sys.argv[1])
duck, _ = specs.connect(spec)
q = [q for q in spec['queries'] if q['id'] == 'q24_edwithin'][0]['duck']
open(sys.argv[2], 'w').write('\n'.join(r[1] for r in duck.execute('EXPLAIN ANALYZE ' + q).fetchall()))
