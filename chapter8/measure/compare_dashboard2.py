"""Compare the panels of dashboard 2 in Spark with those of MobilityDB, keyed by timestamp: the
distances (their number, their instants, their largest difference and their minimum), the
positions and the altitudes of the two aircraft.

    python compare_dashboard2.py <spark answers> <mobilitydb answers>

<spark answers> holds d2_distance.csv, d2_positions.csv, d2_altitude1.csv and d2_altitude2.csv,
the answers of step d2 of run_dashboards.py, and <mobilitydb answers> d2_distance.csv,
d2_positions.csv and d2_altitude.csv, which figures/flights_dashboard2.sql writes."""
import csv
import datetime
import sys

S, M = sys.argv[1], sys.argv[2]
ts = lambda v: datetime.datetime.fromisoformat(v.replace("+00", "").replace("T", " "))
rd = lambda p: list(csv.reader(open(p)))[1:]

md, sd = rd(f"{M}/d2_distance.csv"), rd(f"{S}/d2_distance.csv")
print("distance rows", len(md), len(sd), "same instants",
      [ts(a[0]) for a in md] == [ts(b[0]) for b in sd],
      "max |diff| km", max(abs(float(a[1]) - float(b[1])) for a, b in zip(md, sd)),
      "min km", min(float(b[1]) for b in sd), min(float(a[1]) for a in md))
mp, sp = rd(f"{M}/d2_positions.csv"), rd(f"{S}/d2_positions.csv")
print("positions rows", len(mp), len(sp), "equal",
      [(ts(a[0]), a[1], float(a[2]), float(a[3])) for a in mp] ==
      [(ts(b[0]), b[1], float(b[2]), float(b[3])) for b in sp])
ma = rd(f"{M}/d2_altitude.csv")
sa = [(ts(r[0]), "1", r[1]) for r in rd(f"{S}/d2_altitude1.csv")] + \
     [(ts(r[0]), "2", r[1]) for r in rd(f"{S}/d2_altitude2.csv")]
print("altitude rows", len(ma), len(sa), "equal",
      [(ts(a[0]), a[1], float(a[2]) if a[2] else None) for a in ma] ==
      [(t, k, float(v) if v else None) for t, k, v in sa])
