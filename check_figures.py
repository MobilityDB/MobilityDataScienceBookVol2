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
"""Check, per chapter of the book, that every figure drawn from data has its script here.

From FIGURES.md: the figures drawn by a script, the drawings, and any other row; the scripts it
names that this repository does not hold; the figure files of figs/chapN that the book includes
and no row of FIGURES.md names; and the local paths (/mnt/..., C:\\..., /home/...) left in the
text of each chapter.

Usage: python3 check_figures.py <directory of the LaTeX sources of the book>
"""
import os
import re
import subprocess
import sys

REPO, BOOK = os.path.dirname(os.path.abspath(__file__)), sys.argv[1]
tree = set(subprocess.run(['git', '-C', REPO, 'ls-tree', '-r', '--name-only', 'HEAD'],
                          capture_output=True, text=True, check=True).stdout.split())
figmd = subprocess.run(['git', '-C', REPO, 'show', 'HEAD:FIGURES.md'],
                       capture_output=True, text=True, check=True).stdout
chap, rows = None, {}
for line in figmd.splitlines():
    m = re.match(r'### Chapter (\d+)', line) or re.match(r'### (Appendix.*)', line)
    if m:
        chap = m.group(1)
        rows[chap] = []
        continue
    if chap and line.startswith('| ') and not line.startswith('| Figure') and '---' not in line:
        cells = [c.strip() for c in line.strip('|').split('|')]
        if len(cells) >= 4:
            rows[chap].append(cells)
EXT = ('.py', '.sh', '.sql', '.ipynb', '.java', '.R')
# The figure files the book includes, comments removed
included = set()
for root, _, names in os.walk(BOOK):
    for n in names:
        if n.endswith('.tex') and (root == BOOK or '/figs' in root):
            text = open(os.path.join(root, n), encoding='utf-8', errors='replace').read()
            text = '\n'.join(re.sub(r'(?<!\\)%.*', '', l) for l in text.splitlines())
            for m in re.findall(r'\\(?:includegraphics|input)(?:\[[^\]]*\])?\{([^}]+)\}', text):
                included.add(os.path.splitext(os.path.basename(m))[0])
for chap, rs in rows.items():
    script = [r for r in rs if any(e in r[3] for e in EXT)]
    drawing = [r for r in rs if r not in script and
               ('Drawing' in r[3] or 'TikZ' in r[3] or 'diagram' in r[3].lower())]
    other = [r for r in rs if r not in script and r not in drawing]
    named = set(re.findall(r'`([^`]+\.(?:py|sh|sql|ipynb|java|R))`', ' '.join(r[3] for r in rs)))
    missing = sorted(n for n in named if n not in tree)
    files = set()
    for r in rs:
        for f in re.findall(r'`([^`]+)`', r[2]):
            files.add(os.path.splitext(f)[0])
    d = os.path.join(BOOK, 'figs', f'chap{chap}') if chap.isdigit() else None
    unlisted = []
    if d and os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            stem, ext = os.path.splitext(f)
            if ext.lower() in ('.pdf', '.png', '.jpg', '.jpeg') and stem not in files \
                    and not stem.endswith('_overlay') and stem in included:
                unlisted.append(f)
    print(f'CH {chap}: rows={len(rs)} script={len(script)} drawing={len(drawing)} '
          f'other={len(other)} missing_scripts={missing} unlisted_files={len(unlisted)}')
    for r in other:
        print('   other:', r[0], '|', r[3][:90])
    if unlisted:
        print("   unlisted:", " ".join(unlisted))
for n in range(1, 13):
    paths = []
    for g in (f'chapter{n}.tex', f'chapter{n}_ex.tex'):
        p = os.path.join(BOOK, g)
        if os.path.exists(p):
            paths += re.findall(r'(/mnt/[A-Za-z]/[^\s\'"}]+|[A-Z]:\\\\[^\s\'"}]+|/home/[^\s\'"}]+)',
                                open(p, encoding='utf-8', errors='replace').read())
    print(f'LOCAL ch{n}: {len(paths)}', ' '.join(sorted(set(paths))[:6]))
