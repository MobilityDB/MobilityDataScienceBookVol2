#!/usr/bin/env python3
# SPDX-License-Identifier: PostgreSQL
"""Write chapter4/ais_poses.sql of the companion from the AIS listings of chapter4.tex (the use
case of the temporal rigid geometries of vessels), in the order of the chapter.

Usage: python3 check/ais_poses_from_book.py <chapter4.tex> ais_poses.sql
"""
import re
import sys

s = open(sys.argv[1], encoding='utf-8').read()
HEAD = """-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- Vessels from AIS data as temporal rigid geometries: the listings of the AIS
-- use case of the chapter, as the chapter prints them and in its order.
--
-- Runs in the AIS database of the book (ais/build.sh of this repository, the
-- day January 20, 2026), which holds the table AISClean, after
-- load_turbines.sql, which adds the table Turbines:
--   psql -d ais -f ais_poses.sql
-- It creates the tables AISCleanPoly, ShipShape, ShipsRigid and ShipBoxes.
-------------------------------------------------------------------------------
\\timing on
SET TimeZone = 'UTC';
DROP TABLE IF EXISTS ShipBoxes, ShipsRigid, ShipShape, AISCleanPoly CASCADE;
"""
body = []
for m in re.finditer(r'\\begin\{lstlisting\}(\[[^\]]*\])?\n(.*?)\\end\{lstlisting\}', s, re.S):
    sql = m.group(2).rstrip()
    if not re.search(r'\b(AISClean|AISCleanPoly|ShipShape|ShipsRigid)\b', sql):
        continue
    line = s.count('\n', 0, m.start()) + 1
    if sql.startswith('SELECT MMSI, tgeompoint(Trip) FROM ShipsRigid;'):
        body.append('-- The two layers of the MOVE plugin of QGIS: every vessel of the day, as a\n'
                    '-- temporal point and as a temporal rigid geometry; the rows go to no file\n'
                    '\\o /dev/null\n' + sql + '\n\\o')
    else:
        body.append(sql)
open(sys.argv[2], 'w').write(HEAD + '\n' + '\n\n'.join(body) + '\n')
print(len(body), 'listings')
