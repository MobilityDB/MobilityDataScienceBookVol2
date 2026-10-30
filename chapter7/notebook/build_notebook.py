#!/usr/bin/env python3
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
"""Build a notebook of chapter 7 of the companion from the listings of chapter7.tex that
listings.py writes: one code cell per listing, as the chapter prints it, in its order, preceded by
the statement of its query.
- ais: mobilityDuckAIS.ipynb, from ais_listings.json;
- hanoi: hanoi-book.ipynb, from hanoi_listings.json; its first cell runs load/hanoi_duckdb.sql,
  which reads the Hanoi tables from PostgreSQL, since the chapter shows no listing loading them.

Usage: python3 build_notebook.py ais|hanoi <listings.json> <out.ipynb>
"""
import json
import os
import re
import sys

dataset = sys.argv[1]
listings = json.load(open(sys.argv[2]))

plain = lambda tex: re.sub(r'\s+', ' ', re.sub(
    r'\\[a-zA-Z]+\{([^}]*)\}', r'\1',
    tex.replace('\\"o', 'ö').replace('\\emph{', '').replace('\\textsf{', '')
).replace('}', '').replace('~', ' ')).strip()
md = lambda text: {'cell_type': 'markdown', 'metadata': {}, 'source': text}
code = lambda text: {'cell_type': 'code', 'execution_count': None, 'metadata': {}, 'outputs': [],
                     'source': text}


def preamble(variables, database, extra=''):
    """The first code cell of a notebook, the one mobilityDuckAIS.ipynb has always opened with,
    for the variables and the database file of a dataset: the variables read from the
    environment, a new database file, and the helper `#run` of the notebooks, which runs the
    statements of a listing and shows the first rows of the answer of the last one."""
    return code('import os\n\nimport duckdb\nimport pandas as pd\n\n'
                + ''.join(f"{v} = os.environ['{v}']\n" for v in variables)
                + 'print(duckdb.__version__)\n\n'
                '# The listings create their tables as the chapter prints them, so every run starts\n'
                '# from a new database file\n'
                f"for f in ('{database}', '{database}.wal'):\n"
                '    if os.path.exists(f):\n'
                '        os.remove(f)\n'
                f"con = duckdb.connect('{database}', config={{'allow_unsigned_extensions': 'true'}})\n"
                "con.execute('INSTALL spatial')\n"
                "con.execute('LOAD spatial')\n" + extra + '\n\n'
                'def run(sql, rows=20):\n'
                '    """Run the statements of a listing one by one and show the first rows of the\n'
                '    answer of the last query among them, the one whose answer the chapter prints: a\n'
                '    SELECT or an EXPLAIN, or a statement answering other columns than the lone status,\n'
                '    Count or Success, of an INSERT, an UPDATE, a LOAD or a CREATE INDEX (a PIVOT is a\n'
                '    CREATE that answers its table). Only these rows are fetched, so that an answer of\n'
                '    millions of rows, such\n'
                '    as that of SELECT * EXCLUDE (SOG) FROM AISInput, stays in DuckDB."""\n'
                + REPLACE +
                '    shown = None\n'
                '    for st in con.extract_statements(sql):\n'
                '        rel = con.execute(st)\n'
                '        cols = [d[0] for d in rel.description] if rel.description else []\n'
                '        if cols and (st.type in (duckdb.StatementType.SELECT, duckdb.StatementType.EXPLAIN)\n'
                "                     or cols not in (['Count'], ['Success'])):\n"
                '            shown = pd.DataFrame(rel.fetchmany(rows), columns=cols)\n'
                '    return shown')


if dataset == 'ais':
    SECTIONS = [(0, 300, '## DuckDB: loading the AIS reports and SQL features\n\n'
                 'The listings of Sect. "DuckDB" on the raw AIS reports of January 20, 2026, '
                 'loaded from the file `aisdk-2026-01-20.csv` of the Danish Maritime Authority '
                 '(Appendix "The AIS Database of the Book").'),
                (300, 1200, '## Querying DuckDB\n\nThe queries of Sect. "Querying DuckDB" on the '
                 'table `AISInput`.'),
                (1200, 10**6, '## MobilityDuck: AIS trajectories\n\nThe queries of Sect. "Querying '
                 'MobilityDuck" on the table `Ships` of the AIS database of the book, read from '
                 'PostgreSQL with `postgres_scan`.')]
    REPLACE = ("    sql = (sql.replace(\"'aisdk-2026-01-20.csv'\", f\"'{AIS_DIR}/aisdk-2026-01-20.csv'\")\n"
               "              .replace(\"'/path/to/mobilityduck.duckdb_extension'\", f\"'{MOBILITYDUCK_EXTENSION}'\")\n"
               "              .replace(\"'{conn_str}'\", f\"'{PG_AIS}'\"))\n")
    cells = [md('# MobilityDuck and DuckDB on the AIS data of the book (Chapter 7)\n\n'
                'Every listing of Chapter 7 that reads the AIS data, in the order of the chapter, '
                'with the answer the chapter prints as a comment. Set before starting Jupyter:\n\n'
                '- `AIS_DIR`: the directory of `aisdk-2026-01-20.csv` (`ais/fetch_data.sh day` of this '
                'repository downloads its archive);\n'
                '- `PG_AIS`: the connection string of the AIS database built by `ais/build.sh` '
                '(for example `dbname=ais`);\n'
                '- `MOBILITYDUCK_EXTENSION`: the path of `mobilityduck.duckdb_extension`.\n\n'
                'The notebook runs DuckDB v1.5.6, as the README of this chapter explains.'),
             preamble(['AIS_DIR', 'PG_AIS', 'MOBILITYDUCK_EXTENSION'], 'ais_ch7.duckdb')]
elif dataset == 'hanoi':
    SECTIONS = [(0, 10**6, '## MobilityDuck: BerlinMOD Hanoi\n\nThe queries of Sect. "BerlinMOD '
                 'Hanoi" on the trips of 200 vehicles in Hanoi from June 1 to June 5, 2020.')]
    REPLACE = ("    sql = (sql.replace(\"'${MOBILITYDUCK_EXTENSION}'\", f\"'{MOBILITYDUCK_EXTENSION}'\")\n"
               "              .replace(\"'${PG_HANOI}'\", f\"'{PG_HANOI}'\"))\n")
    loader = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'load',
                               'hanoi_duckdb.sql'), encoding='utf-8').read()
    loader = loader[loader.index('*/') + 2:].strip()
    cells = [md('# MobilityDuck on the BerlinMOD Hanoi data (Chapter 7)\n\n'
                'Every SQL listing of Sect. "BerlinMOD Hanoi" of Chapter 7, in the order of the '
                'chapter. Set before starting Jupyter:\n\n'
                '- `PG_HANOI`: the connection string of the Hanoi database that `load/hanoi_pg.sql` '
                'of this chapter loads (for example `dbname=hanoi`);\n'
                '- `MOBILITYDUCK_EXTENSION`: the path of `mobilityduck.duckdb_extension`.\n\n'
                'The notebook runs DuckDB v1.5.6, as the README of this chapter explains. Its '
                'session is in UTC, as the chapter states, and its first cell reads the tables of the '
                'Hanoi database into DuckDB with `load/hanoi_duckdb.sql`.'),
             preamble(['PG_HANOI', 'MOBILITYDUCK_EXTENSION'], 'hanoi_ch7.duckdb',
                      "con.execute(\"SET TimeZone = 'UTC'\")\n"),
             md('## Loading the Hanoi tables\n\nThe tables of the Hanoi database, read with '
                '`postgres_scan` by `load/hanoi_duckdb.sql`, and their sizes.'),
             code('run("""\n' + loader + '\n""")')]
else:
    sys.exit('dataset: ais or hanoi')

for lo, hi, title in SECTIONS:
    part = [o for o in listings if lo <= o['line'] < hi]
    if not part:
        continue
    cells.append(md(title))
    for o in part:
        if o['query']:
            cells.append(md('*' + plain(o['query']) + '*'))
        cells.append(code('run("""\n' + o['sql'].rstrip() + '\n""")'))

for i, c in enumerate(cells):
    c['id'] = f'cell-{i:02d}'
nb = {'cells': cells, 'metadata': {'kernelspec': {'display_name': 'Python 3', 'language': 'python',
                                                 'name': 'python3'},
                                  'language_info': {'name': 'python'}},
      'nbformat': 4, 'nbformat_minor': 5}
json.dump(nb, open(sys.argv[3], 'w'), indent=1)
print(len(cells), 'cells')
