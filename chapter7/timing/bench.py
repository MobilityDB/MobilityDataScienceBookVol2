"""Alternating warm-cache timings of the same SQL in DuckDB (CLI) and PostgreSQL (psql).

run_duck mirrors MobilityDuck's benchmark runner `#run_sql` (benchmark/BerlinMOD/run_queries.py,
QueryRunner.run_sql): the SQL is piped into the DuckDB CLI through subprocess. It differs in
reading the engine's own `.timer` instead of wall time around the process, so the process start
and the database open are not counted, and run_pg is its psql twin (\\timing). The two engines
are run alternately, round after round, so a load from other processes hits both; only the ratio
of their times is meaningful on a shared machine.

usage: bench.py <spec.json> <out.json> [resume]
spec: {"rounds": 3, "duck_db": path, "duck_setup": [sql...], "pg_db": name, "pg_setup": [sql...],
       "queries": {name: {"file": path, "pg_file": path, "duck_subst": {..}, "pg_subst": {..},
                          "timeout": s, "duck_timeout": s, "once": bool, "rounds": n}}}
The paths of the spec are relative to the folder of the spec file. Each query is run twice per
engine and round; the second (warm) run is recorded, or the only one when "once" is true.

Environment: DUCKDB names the DuckDB shell (default `duckdb`) and PSQL psql (default `psql`);
DUCKDB_DATABASE and PGDATABASE override duck_db and pg_db; the libpq variables (PGHOST, PGPORT,
PGUSER) select the PostgreSQL server. When MOBILITYDUCK_EXTENSION names the file of the
MobilityDuck extension, every DuckDB session loads the spatial extension and that file first.
At the end, the ratio of the PostgreSQL time to the DuckDB time of each round is printed.
"""
import json, os, re, subprocess, sys, time

spec = json.load(open(sys.argv[1]))
here = os.path.dirname(os.path.abspath(sys.argv[1]))
out_path = sys.argv[2]
res = json.load(open(out_path)) if len(sys.argv) > 3 and sys.argv[3] == 'resume' else {}
DUCK = os.environ.get('DUCKDB', 'duckdb')
PSQL = os.environ.get('PSQL', 'psql')
DUCK_DB = os.environ.get('DUCKDB_DATABASE', os.path.join(here, spec['duck_db']))
PG_DB = os.environ.get('PGDATABASE', spec['pg_db'])
EXT = os.environ.get('MOBILITYDUCK_EXTENSION')
DUCK_LOAD = [f"LOAD spatial;\nLOAD '{EXT}';"] if EXT else []


def subst(sql, d):
    for k, v in (d or {}).items():
        sql = sql.replace(k, v)
    return sql


def run_duck(sql, timeout, n=2):
    script = ('\n'.join(DUCK_LOAD + spec.get('duck_setup', [])) + '\n.mode trash\n.timer on\n'
              + (sql + '\n') * n)
    p = subprocess.run([DUCK, '-unsigned', '-readonly', DUCK_DB], input=script,
                       text=True, capture_output=True, timeout=timeout)
    times = [float(x) for x in re.findall(r'Run Time \(s\): real ([0-9.]+)', p.stdout + p.stderr)]
    err = [l for l in (p.stdout + p.stderr).splitlines() if 'Error' in l]
    if err or len(times) < n:
        raise RuntimeError(f'duck: {err} {times}')
    return times[-1]


def run_pg(sql, timeout, n=2):
    script = ('\n'.join(spec.get('pg_setup', [])) + '\n\\o /dev/null\n\\timing on\n'
              + (sql + '\n') * n)
    try:
        p = subprocess.run([PSQL, '-X', '-v', 'ON_ERROR_STOP=1', '-d', PG_DB],
                           input=script, text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None
    times = [float(x) / 1000 for x in re.findall(r'Time: ([0-9.]+) ms', p.stdout + p.stderr)]
    if p.returncode != 0 or len(times) < n:
        raise RuntimeError(f'pg: {p.stderr[-500:]} {times}')
    return times[-1]


for name, q in spec['queries'].items():
    sql = open(os.path.join(here, q['file'])).read()
    pg_sql = open(os.path.join(here, q.get('pg_file', q['file']))).read()
    r = res.setdefault(name, {'duck': [], 'pg': []})
    for rnd in range(q.get('rounds', spec['rounds'])):
        if len(r['duck']) > rnd and len(r['pg']) > rnd:
            continue
        n = 1 if q.get('once') else 2
        d = run_duck(subst(sql, q.get('duck_subst')), q.get('duck_timeout', 3600), n)
        pg = run_pg(subst(pg_sql, q.get('pg_subst')), q.get('timeout', 3600), n)
        r['duck'].append(d)
        r['pg'].append(pg)
        print(f'{time.strftime("%H:%M:%S")} {name} round {rnd}: duck {d:.3f}s pg {pg}', flush=True)
        json.dump(res, open(out_path, 'w'), indent=1)
        if pg is None:
            break
for name, r in res.items():
    ratios = [p / d for d, p in zip(r['duck'], r['pg']) if d and p]
    if ratios:
        print(f'{name}: PostgreSQL took between {min(ratios):.1f} and {max(ratios):.1f} '
              'times longer than DuckDB', flush=True)
