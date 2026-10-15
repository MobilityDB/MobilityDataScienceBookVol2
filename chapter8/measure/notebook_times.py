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
