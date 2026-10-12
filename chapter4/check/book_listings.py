#!/usr/bin/env python3
# SPDX-License-Identifier: PostgreSQL
"""Run the SQL listings of the type sections of chapter4.tex and compare each
answer with the result the book prints under it.

The type sections run from Sect. Rigid Moving Objects up to Sect. Temporal
Distance between Rigid Geometries. Statements that read a table of the case
studies are skipped: the scripts of the case studies reproduce them.

Two phases around a psql run: `extract` writes the statements, each after an
\echo of its number, into a .sql file that psql runs on any database with
MobilityDB, and `compare` reads the answers psql printed.

usage:
  python3 book_listings.py extract <chapter4.tex> <listings.sql>
  psql -X -d <database> -f <listings.sql> > <listings.out> 2>&1
  python3 book_listings.py compare <chapter4.tex> <listings.out> <pose_examples.sql>

`compare` prints one line per statement whose answer differs from the book and
writes <pose_examples.sql>, the statements in the order of the chapter, each
followed by the answer the database gave.
"""
import re
import sys

MARK = "@@ statement "
TABLES = re.compile(r"\b(Ships|ShipShape|AISInput\w*|ego_pose|sample_annotation)\b", re.I)

def statements(tex):
    """Return the (section, sql, book result) of every listing statement, in order"""
    src = open(tex, encoding="utf-8").read()
    i = src.index("\\section{Rigid Moving Objects}")
    j = src.index("\\section{Temporal Distance between Rigid Geometries}")
    body = src[i:j]
    # a red heading is \texorpdfstring{\textcolor{red}{T}}{T}: its plain form is the last group
    heads = [(m.start(), re.sub(r"^\\texorpdfstring\{.*\}\{([^{}]*)\}$", r"\1", m.group(1)))
             for m in re.finditer(r"\\(?:sub)?section\{(.*)\}\n", body)]
    result = []
    for m in re.finditer(r"\\begin\{lstlisting\}\[language=mySQL\]\n(.*?)\\end\{lstlisting\}",
                         body, re.S):
        sec = ""
        for p, n in heads:
            if p <= m.start():
                sec = n
        cur, exp, incomment = [], [], False
        # a statement ends at a semicolon closing a line outside a string literal
        ended = lambda: bool(cur) and cur[-1].rstrip().endswith(";") and \
            "\n".join(cur).count("'") % 2 == 0
        for line in m.group(1).rstrip("\n").split("\n"):
            s = line.strip()
            if incomment:
                exp.append(s.replace("*/", ""))
                incomment = "*/" not in s
                continue
            if s.startswith("--") and ended():
                exp.append(s[2:].strip())
                continue
            if s.startswith("--") or not s:
                continue
            if s.startswith("/*") and ended():
                exp.append(s[2:].replace("*/", "").strip())
                incomment = "*/" not in s
                continue
            if ended():
                result.append((sec, "\n".join(cur), " ".join(exp).strip()))
                cur, exp = [], []
            cur.append(line)
        if cur:
            result.append((sec, "\n".join(cur), " ".join(exp).strip()))
    return [r for r in result if not TABLES.search(r[1])]

def norm(t):
    """Return an answer without the differences of presentation that the book
    elides: blank space, the column separator of psql, a time of day of midnight
    and the abbreviated Booleans"""
    t = re.sub(r"\(up to floating-point rounding\)", "", t)
    t = re.sub(r" 00:00:00(\+00)?", "", t)
    t = t.replace("|", "")
    if t.strip() == "t":
        t = "true"
    if t.strip() == "f":
        t = "false"
    return re.sub(r"\s+", "", t)

if sys.argv[1] == "extract":
    stmts = statements(sys.argv[2])
    with open(sys.argv[3], "w") as f:
        f.write("SET TimeZone = 'UTC';\nSET DateStyle = 'ISO, YMD';\n\\pset tuples_only on\n"
                "\\pset format unaligned\n")
        for k, (sec, sql, exp) in enumerate(stmts):
            f.write(f"\\echo '{MARK}{k}'\n{sql}\n")
    print(f"{len(stmts)} statements written")
elif sys.argv[1] == "compare":
    stmts = statements(sys.argv[2])
    out = open(sys.argv[3], encoding="utf-8").read()
    parts = re.split(re.escape(MARK) + r"(\d+)\n", out)
    answers = {int(parts[k]): parts[k + 1].strip() for k in range(1, len(parts) - 1, 2)}
    lines = ["-- SPDX-License-Identifier: PostgreSQL",
             "-" * 79,
             "-- Mobility Data Science: In-Memory, Large-Scale and Stream Processing",
             "-- Chapter 4: Temporal Poses and Temporal Rigid Geometries",
             "--",
             "-- The worked examples of the type sections, in the order of the chapter",
             "--",
             "-- Needs no dataset. The comment under each statement is the answer it",
             "-- produced, which is the result the book prints under it.",
             "--",
             "-- Last run against PostgreSQL 18.6, PostGIS 3.6.4, MobilityDB 1.4.",
             "-" * 79, "", "SET TimeZone = 'UTC';",
             "-- the example of Comparisons and Spatial Functions creates the table Ship",
             "DROP TABLE IF EXISTS Ship;"]
    last, differ = None, 0
    for k, (sec, sql, exp) in enumerate(stmts):
        got = answers.get(k, "<no answer>")
        # the runner echoes each statement before its answer
        if got.startswith(sql):
            got = got[len(sql):].strip()
        if sec != last:
            while lines[-1] == "":
                lines.pop()
            lines += ["", "", "-" * 79, f"-- {sec}", "-" * 79, ""]
            last = sec
        lines += [sql] + ["-- " + l for l in got.split("\n")] + [""]
        if exp and norm(got) != norm(exp):
            differ += 1
            print(f"DIFFERS [{sec}] {sql.splitlines()[0][:70]}\n   book: {exp}\n   db  : {got}")
    open(sys.argv[4], "w").write("\n".join(lines).rstrip("\n") + "\n")
    print(f"statements: {len(stmts)}, answered: {len(answers)}, differ from the book: {differ}")
