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

"""The wall time of each code cell of an executed notebook, its errors and the last two rows of
the tables it prints, from the timestamps that nbconvert records in the metadata of each cell
(metadata.execution), and the sum of the times of the cells.

    python notebook_times.py <executed notebook>
"""
import datetime as d
import json
import sys

nb = json.load(open(sys.argv[1]))
total = 0
for i, c in enumerate(nb["cells"]):
    if c["cell_type"] != "code":
        continue
    m = c["metadata"].get("execution", {})
    a, b = m.get("iopub.execute_input"), m.get("shell.execute_reply")
    dur = ((d.datetime.fromisoformat(b.replace("Z", "+00:00")) -
            d.datetime.fromisoformat(a.replace("Z", "+00:00"))).total_seconds() if a and b else 0)
    total += dur
    errs = [o.get("ename") for o in c["outputs"] if o["output_type"] == "error"]
    txt = "".join(o["text"] if isinstance(o["text"], str) else "".join(o["text"])
                  for o in c["outputs"] if o["output_type"] == "stream")
    rows = [line for line in txt.splitlines() if line.startswith("|")][-2:]
    print(i, f"{dur:.1f}", errs or "", *rows, sep="  ")
print("sum of cells", f"{total:.1f}")
