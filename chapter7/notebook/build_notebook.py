#!/usr/bin/env python3
# SPDX-License-Identifier: PostgreSQL
"""Build chapter7/mobilityDuckAIS.ipynb of the companion from the AIS listings of chapter7.tex
(ais_listings.json, written by ais_listings.py): one code cell per listing, as the chapter prints
it, in its order, preceded by the statement of its query.

Usage: python3 build_notebook.py <ais_listings.json> <out.ipynb>
"""
import json
import re
import sys

listings = json.load(open(sys.argv[1]))

plain = lambda tex: re.sub(r'\s+', ' ', re.sub(
    r'\\[a-zA-Z]+\{([^}]*)\}', r'\1',
    tex.replace('\\"o', 'ö').replace('\\emph{', '').replace('\\textsf{', '')
).replace('}', '').replace('~', ' ')).strip()
md = lambda text: {'cell_type': 'markdown', 'metadata': {}, 'source': text}
code = lambda text: {'cell_type': 'code', 'execution_count': None, 'metadata': {}, 'outputs': [],
                     'source': text}

SECTIONS = [(0, 300, '## DuckDB: loading the AIS reports and SQL features\n\n'
             'The listings of Sect. "DuckDB" on the raw AIS reports of January 20, 2026, '
             'loaded from the file `aisdk-2026-01-20.csv` of the Danish Maritime Authority '
             '(Appendix "The AIS Database of the Book").'),
            (300, 1200, '## Querying DuckDB\n\nThe queries of Sect. "Querying DuckDB" on the '
             'table `AISInput`.'),
            (1200, 10**6, '## MobilityDuck: AIS trajectories\n\nThe queries of Sect. "Querying '
             'MobilityDuck" on the table `Ships` of the AIS database of the book, read from '
             'PostgreSQL with `postgres_scan`.')]

cells = [md('# MobilityDuck and DuckDB on the AIS data of the book (Chapter 7)\n\n'
            'Every listing of Chapter 7 that reads the AIS data, in the order of the chapter, '
            'with the answer the chapter prints as a comment. Set before starting Jupyter:\n\n'
            '- `AIS_DIR`: the directory of `aisdk-2026-01-20.csv` (`ais/fetch_data.sh day` of this '
            'repository downloads its archive);\n'
            '- `PG_AIS`: the connection string of the AIS database built by `ais/build.sh` '
            '(for example `dbname=ais`);\n'
            '- `MOBILITYDUCK_EXTENSION`: the path of `mobilityduck.duckdb_extension`.\n\n'
            'The notebook runs DuckDB v1.5.5, as the README of this chapter explains.'),
         code('import os\n\nimport duckdb\nimport pandas as pd\n\n'
              "AIS_DIR = os.environ['AIS_DIR']\n"
              "PG_AIS = os.environ['PG_AIS']\n"
              "MOBILITYDUCK_EXTENSION = os.environ['MOBILITYDUCK_EXTENSION']\n"
              'print(duckdb.__version__)\n\n'
              '# The listings create their tables as the chapter prints them, so every run starts\n'
              '# from a new database file\n'
              "for f in ('ais_ch7.duckdb', 'ais_ch7.duckdb.wal'):\n"
              '    if os.path.exists(f):\n'
              '        os.remove(f)\n'
              "con = duckdb.connect('ais_ch7.duckdb', config={'allow_unsigned_extensions': 'true'})\n"
              "con.execute('INSTALL spatial FROM core_nightly')\n"
              "con.execute('LOAD spatial')\n\n\n"
              'def run(sql, rows=20):\n'
              '    """Run the statements of a listing and show the first rows of the answer of the\n'
              '    last one; only these rows are fetched, so that an answer of millions of rows, such\n'
              '    as that of SELECT * EXCLUDE (SOG) FROM AISInput, stays in DuckDB."""\n'
              "    sql = (sql.replace(\"'aisdk-2026-01-20.csv'\", f\"'{AIS_DIR}/aisdk-2026-01-20.csv'\")\n"
              "              .replace(\"'/path/to/mobilityduck.duckdb_extension'\", f\"'{MOBILITYDUCK_EXTENSION}'\")\n"
              "              .replace(\"'{conn_str}'\", f\"'{PG_AIS}'\"))\n"
              '    rel = con.execute(sql)\n'
              '    if not rel.description:\n'
              '        return None\n'
              '    return pd.DataFrame(rel.fetchmany(rows), columns=[d[0] for d in rel.description])')]
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
json.dump(nb, open(sys.argv[2], 'w'), indent=1)
print(len(cells), 'cells')
