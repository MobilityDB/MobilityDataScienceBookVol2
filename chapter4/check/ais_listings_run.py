#!/usr/bin/env python3
# SPDX-License-Identifier: PostgreSQL
"""Run every SQL listing of the AIS use case of chapter4.tex on the AIS database
and report, per statement, its row count, its time and its error.

The book does not print the answers of the AIS use case, so a statement is
checked for running to its end, not for its answer. A query's rows are read
through a server-side cursor, in batches, so that every column of every row is
computed, as when the listing is run by hand, without holding a whole column of
temporal rigid geometries in memory. The statements are split as #statements of
book_listings.py splits the listings of the type sections.

The tables AISInputFilteredPoly and ShipShape must exist (ais_poses.sql builds
them); their CREATE statements are skipped, and the one of Ships is run.

As the export scripts of the figures do (figures/figlib.py), the database comes
from the PostgreSQL environment variables (PGHOST, PGPORT, PGUSER) and its name
from AIS_DB (default: ais).

usage: python3 ais_listings_run.py <chapter4.tex>
"""
import os
import re
import sys
import time
import psycopg2

BATCH = 1000

src = open(sys.argv[1], encoding="utf-8").read()
i = src.index("\\section{Use Case: Vessels from AIS Data}")
j = src.index("\\section{Use Case:", i + 10)
body = src[i:j]
heads = [(m.start(), m.group(1)) for m in re.finditer(r"\\subsection\{(.*)\}\n", body)]


def split(txt):
    """The statements of a listing, ended by a semicolon outside a literal"""
    out, cur = [], []
    for l in txt.split("\n"):
        if l.strip().startswith("--") or not l.strip():
            continue
        cur.append(l)
        j = "\n".join(cur)
        if l.rstrip().endswith(";") and j.count("'") % 2 == 0:
            out.append(j.rstrip().rstrip(";"))
            cur = []
    return out


def rows_of(conn, sql):
    """The number of rows of a query, every row read from a server-side cursor"""
    n = 0
    with conn.cursor(name="listing") as cur:
        cur.itersize = BATCH
        cur.execute(sql)
        while True:
            batch = cur.fetchmany(BATCH)
            if not batch:
                return n
            n += len(batch)


conn = psycopg2.connect(dbname=os.environ.get("AIS_DB", "ais"),
    options="-c TimeZone=Europe/Copenhagen -c statement_timeout=3600000")
for m in re.finditer(r"\\begin\{lstlisting\}\[language=mySQL[^\]]*\]\n(.*?)\\end\{lstlisting\}", body, re.S):
    sec = [n for p, n in heads if p <= m.start()][-1]
    for st in split(m.group(1)):
        head = re.sub(r"\s+", " ", st)[:80]
        if re.match(r"CREATE TABLE (AISInputFilteredPoly|ShipShape)\b", st, re.I):
            print(f"[{sec}] SKIPPED (exists) {head}", flush=True)
            continue
        t0 = time.time()
        try:
            if re.match(r"\s*(SELECT|WITH)\b", st, re.I):
                res = rows_of(conn, st)
            else:
                if re.match(r"\s*CREATE TABLE Ships\b", st, re.I):
                    with conn.cursor() as cur:
                        cur.execute("DROP TABLE IF EXISTS Ships CASCADE")
                with conn.cursor() as cur:
                    cur.execute(st)
                    res = cur.rowcount
            conn.commit()
            print(f"[{sec}] OK rows={res} {time.time() - t0:.1f}s  {head}", flush=True)
        except psycopg2.Error as e:
            conn.rollback()
            print(f"[{sec}] ERROR {time.time() - t0:.1f}s  {head}\n    {str(e).splitlines()[0]}", flush=True)
conn.close()
