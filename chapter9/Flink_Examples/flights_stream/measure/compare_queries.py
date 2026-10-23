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

"""Compare the answers of the continuous queries 3 and 4 of flights_queries.py, the dumps
airborne-hourly.json and holding.json that queries_session.sh writes, with the answers of
MobilityDB, out/flights_stream_queries_q3.csv and out/flights_stream_queries_q4.csv that
flights/flights_stream_queries.sql writes: for query 3 the hours, their peaks, the instants of
the peaks and their averages; for query 4 the passes near a fix of each engine, keyed by fix,
aircraft and start of the session to the millisecond, those with the same periods, those of 10
minutes or more and the five longest of Flink. The helpers ts, periods and seconds read the text
of a timestamp and of a span set.

    python compare_queries.py <session out> <flights/out>"""
import csv
import json
import re
import sys
from datetime import datetime

OUT, BASE = sys.argv[1], sys.argv[2]


def ts(s):
    return datetime.fromisoformat(s.replace("+00", "").strip())


def periods(text):
    """The periods of a tstzspanset text as (start, end) datetimes."""
    return [(ts(a), ts(b)) for a, b in re.findall(r"[\[(]([^,]+), ([^\])]+)[\])]", text)]


def seconds(ps):
    return sum((b - a).total_seconds() for a, b in ps)


# Query 3: one row per hour
flink = {r["window_start"][:13]: r for r in map(json.loads, open(f"{OUT}/airborne-hourly.json"))}
mdb = {r["hour"][:13]: r for r in csv.DictReader(open(f"{BASE}/flights_stream_queries_q3.csv"))}
hours = sorted(set(flink) | set(mdb))
same_peak = sum(1 for h in hours if h in flink and h in mdb and
                int(flink[h]["peak"]) == int(mdb[h]["peak"]))
same_time = sum(1 for h in hours if h in flink and h in mdb and
                ts(flink[h]["peak_time"]) == ts(mdb[h]["peaktime"]))
print(f"q3 hours flink={len(flink)} mdb={len(mdb)} same peak={same_peak} same peak time={same_time}")
for h in hours:
    f, m = flink.get(h), mdb.get(h)
    if f and m:
        print(f"  {h} instants {f['instants']}/{m['instants']} peak {f['peak']}/{m['peak']} "
              f"avg {float(f['average']):.3f}/{float(m['average']):.3f}")
    else:
        print(f"  {h} only in {'flink' if f else 'mdb'}")


def key(fix, icao24, start):
    """A pass: its fix, its aircraft and the start of its session, to the millisecond."""
    t = ts(start)
    return fix, icao24, t.replace(microsecond=t.microsecond // 1000 * 1000)


# Query 4: one row per fix and flight
fl = {key(r["fix"], r["icao24"], r["session_start"]): r
      for r in map(json.loads, open(f"{OUT}/holding.json"))}
md = {key(r["fix"], r["icao24"], r["sessionstart"]): r
      for r in csv.DictReader(open(f"{BASE}/flights_stream_queries_q4.csv"))}
both = set(fl) & set(md)
equal = [k for k in both if fl[k]["periods"].replace("+00", "") == md[k]["periods"].replace("+00", "")]
diff = sorted(both - set(equal))
print(f"q4 passes flink={len(fl)} mdb={len(md)} matched={len(both)} equal periods={len(equal)}")
print(f"  only flink={len(set(fl) - set(md))} only mdb={len(set(md) - set(fl))}")
long_f = sum(1 for r in fl.values() if seconds(periods(r["periods"])) >= 600)
long_m = sum(1 for r in md.values() if seconds(periods(r["periods"])) >= 600)
print(f"  holding 10 min or more flink={long_f} mdb={long_m}")
top = sorted(fl.values(), key=lambda r: -seconds(periods(r["periods"])))[:5]
for r in top:
    print(f"  {r['fix']} {r['icao24']} {r['callsign']} {seconds(periods(r['periods'])):.6f} s "
          f"{float(r['length']) / 1000:.1f} km")
for k in diff[:10]:
    print("  differ", k, seconds(periods(fl[k]["periods"])), seconds(periods(md[k]["periods"])))
