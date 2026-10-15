"""Compare the rows of dashboard 1 in Spark with those of MobilityDB: the number of rows of each,
the rows of one engine only, keyed by aircraft, call sign and instant, the largest difference of
the altitude, the vertical rate, the longitude and the latitude between the rows of both, and the
flights and the aircraft of Spark.

    python compare_dashboard1.py <mobilitydb output> <spark d1.csv>

<mobilitydb output> is the output of psql for flights/flights_dashboards.sql, which
flights/run_all.sh writes into out/flights_dashboards.out, and <spark d1.csv> the answer of step
d1 of run_dashboards.py."""
import csv
import datetime
import sys

lines = open(sys.argv[1]).read().splitlines()
start = next(i for i, l in enumerate(lines)
             if l.replace(" ", "").startswith("icao24|callsign|geoaltitude"))
mdb = []
for l in lines[start + 2:]:
    if l.startswith("("):
        break
    mdb.append([c.strip() for c in l.split("|")])
spark = list(csv.reader(open(sys.argv[2])))[1:]
print("rows", len(mdb), len(spark))
m = {(r[0], r[1], datetime.datetime.fromisoformat(r[6].replace("+00", "").replace("T", " "))): r for r in mdb}
s = {(r[0], r[1], datetime.datetime.fromisoformat(r[6].replace("+00", "").replace("T", " "))): r for r in spark}
print("keys only in MobilityDB", len(m.keys() - s.keys()), "only in Spark", len(s.keys() - m.keys()))
worst = [0.0] * 4
for k in m.keys() & s.keys():
    for j in range(4):
        worst[j] = max(worst[j], abs(float(m[k][2 + j]) - float(s[k][2 + j])))
print("max |difference| altitude, vertrate, lon, lat:", worst)
print("flights", len({(r[0], r[1]) for r in spark}), "aircraft", len({r[0] for r in spark}))
print(mdb[0], spark[0], sep="\n")
