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
"""Execute a notebook in place with the kernel of this Python, timing each cell, and print the
first lines of the output of every code cell.

Usage: python run_notebook.py <in.ipynb> <out.ipynb>
"""
import sys
import time

import nbformat
from nbclient import NotebookClient

nb = nbformat.read(sys.argv[1], as_version=4)
t0 = time.time()
client = NotebookClient(nb, timeout=None, kernel_name='python3', allow_errors=False)
client.execute()
nbformat.write(nb, sys.argv[2])
print(f'executed in {time.time() - t0:.0f} s')
for i, c in enumerate(nb.cells):
    if c.cell_type != 'code':
        continue
    text = []
    for o in c.get('outputs', []):
        if 'text' in o:
            text.append(o['text'])
        elif 'data' in o and 'text/plain' in o['data']:
            text.append(o['data']['text/plain'])
    print(f'--- cell {i}:', ' | '.join(' '.join(text).splitlines()[:4])[:300])
