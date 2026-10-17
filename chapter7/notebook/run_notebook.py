#!/usr/bin/env python3
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
