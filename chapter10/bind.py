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
"""Bind the parameters of the queries of chapter 10 to a window of MobilityLakehouse.

The regions and windows are those of benchmark/planar/windows_25832.csv of the MobilityLakehouse
checkout named by $LAKEHOUSE, the file 70_queries.py of that repository reads: a row per region
and window, named <region>_<window>, with its box in EPSG:25832 and its two instants in UTC. Each
statement of queries.sql is preceded by `-- @region <region>` (ports, goteborg or belt, ports
meaning rodby_port for the parameters :a... and puttgarden for :b...) and possibly by
`-- @gate <meters>`, the region and gate `QUERIES` of 70_queries.py gives each query.

`#values` mirrors `#statements` of 70_queries.py, which computes the same parameters, except that
a parameter of the chapter written inside a quoted literal, such as a bound of an stbox, takes the
text of its value, and outside a typed literal (70_queries.py names the two forms :t0s and :t0).
`#bind` mirrors `#bind` of 70_queries.py: longest name first, so that :t0 never eats :t0s, and an
unbound parameter is an error. The bound script starts with the view `trips` over the files of a
layout, globbed as `#layout_glob` of 70_queries.py does.

usage: python3 bind.py <window> <layout> <queries.sql>   (window: 1h, 1day, 1week, 1month;
       layout: L0 or one of the layouts of the run, e.g. L3)
"""
import csv
import datetime as dt
import os
import re
import sys

window, layout, path = sys.argv[1:4]
lakehouse = os.environ.get('LAKEHOUSE')
if not lakehouse:
    sys.exit('bind.py: set LAKEHOUSE to the MobilityLakehouse checkout')
regions = {}
with open(os.path.join(lakehouse, 'benchmark', 'planar', 'windows_25832.csv')) as f:
    for name, x0, y0, x1, y1, t0, t1 in csv.reader(f):
        region, win = name.rsplit('_', 1)
        if win == window:
            regions[region] = (float(x0), float(y0), float(x1), float(y1),
                               dt.datetime.fromisoformat(t0), dt.datetime.fromisoformat(t1))
if not regions:
    sys.exit(f'bind.py: no window {window} in windows_25832.csv')


def layout_glob(layout):
    """The files of a layout under the run directory, as 70_queries.py globs them"""
    if layout == 'L0':
        return 'L0/year=*/month=*/day-*.parquet'
    if layout in ('L0X', 'L0Z', 'L0H'):
        return f'layouts_daily/{layout}/day-*.parquet'
    if layout in ('L1', 'L2', 'L3', 'L4'):
        return f'layouts_daily/{layout}/day-*/**/*.parquet'
    if layout in ('L1s', 'L2s', 'L3s', 'L4s'):
        return f'layout_compact/{layout}/**/*.parquet'
    sys.exit(f'bind.py: unknown layout {layout}')


def values(region, gate):
    """{parameter: (its text inside a literal, its typed literal)} for a statement on the region"""
    boxes = {'a': regions['rodby_port'], 'b': regions['puttgarden']} if region == 'ports' \
        else {'r': regions[region]}
    t0, t1 = next(iter(boxes.values()))[4:]
    ts = lambda t: t.strftime('%Y-%m-%d %H:%M:%S') + '+00'
    tmid = t0 + (t1 - t0) / 2
    p = {'t0': (ts(t0), f"TIMESTAMPTZ '{ts(t0)}'"), 't1': (ts(t1), f"TIMESTAMPTZ '{ts(t1)}'"),
         'tmid': (ts(tmid), f"TIMESTAMPTZ '{ts(tmid)}'"),
         'd0': (str(t0.date()), f"DATE '{t0.date()}'"), 'd1': (str(t1.date()), f"DATE '{t1.date()}'")}
    for k, (x0, y0, x1, y1, _, _) in boxes.items():
        for name, v in (('xmin', x0), ('ymin', y0), ('xmax', x1), ('ymax', y1)):
            p[k + name] = (repr(v), repr(v))
    if gate is not None:
        p['gate'] = (gate, gate)
    return p


def bind(stmt, p):
    """The statement with each parameter replaced, by its text inside quotes and typed outside"""
    parts = stmt.split("'")
    for i, part in enumerate(parts):
        for name in sorted(p, key=len, reverse=True):
            part = part.replace(':' + name, p[name][0 if i % 2 else 1])
        parts[i] = part
    out = "'".join(parts)
    left = re.findall(r'(?<![:\w]):[a-z][a-z0-9]*\b', re.sub(r'--[^\n]*', '', out))
    if left:
        sys.exit(f'bind.py: unbound parameters {sorted(set(left))}')
    return out


text = open(path, encoding='utf-8').read()
print(".bail on\n.mode markdown\n.timer on\nINSTALL spatial FROM core_nightly;\nLOAD spatial;\n"
      "LOAD '${MOBILITYDUCK_EXTENSION}';\nSET TimeZone = 'UTC';")
print(f"CREATE OR REPLACE VIEW trips AS\nSELECT * FROM read_parquet('${{LAKEHOUSE_RUN}}/"
      f"{layout_glob(layout)}', union_by_name = true);")
for block in re.split(r'\n(?=-- @region )', text)[1:]:
    region = re.match(r'-- @region (\w+)', block).group(1)
    gate = re.search(r'^-- @gate (\d+)', block, re.M)
    print(bind(block.rstrip() + '\n', values(region, gate.group(1) if gate else None)))
