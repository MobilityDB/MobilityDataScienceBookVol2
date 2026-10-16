"""Read a timing spec of this directory and open its two connections.

A spec is {"rounds": 3, "duck": {"database", "read_only", "extensions", "setup"},
"pg": {"conninfo", "setup"}, "queries": [{"id", "duck", "pg"}]}. Its strings may name the
environment variables of the README of this chapter (${CH7_DB_DIR}, ${MOBILITYDUCK_EXTENSION},
${PG_AIS}, ${PG_HANOI}), which are expanded when the spec is read; `extensions` are what
load_extension takes, and `setup` statements run once per connection.

The companion has no shared helper that opens DuckDB and PostgreSQL in one process: the nearest
is #psql of chapter11/figures/export_hermite.py, which runs one statement through psql. This
module holds the connection code that bench.py, bench_sample.py and bench_close_forms.py of this
directory share.
"""
import json
import os
import subprocess

import duckdb
import psycopg


def expand(o):
    if isinstance(o, dict):
        return {k: expand(v) for k, v in o.items()}
    if isinstance(o, list):
        return [expand(v) for v in o]
    if isinstance(o, str):
        e = os.path.expandvars(o)
        if '${' in e:
            raise SystemExit(f'unset environment variable in {o!r}')
        return e
    return o


def load(path):
    return expand(json.load(open(path)))


def connect(spec):
    d, p = spec['duck'], spec['pg']
    duck = duckdb.connect(d['database'], read_only=d.get('read_only', True),
                          config={'allow_unsigned_extensions': 'true'})
    for ext in d.get('extensions', []):
        duck.load_extension(ext)
    for s in d.get('setup', []):
        duck.execute(s)
    pg = psycopg.connect(p['conninfo'], autocommit=True)
    for s in p.get('setup', []):
        pg.execute(s)
    return duck, pg


def load_average():
    return subprocess.run(['uptime'], capture_output=True, text=True).stdout.split('load average:')[1].strip()
