"""Dump the output topics of the walk and of the dashboards job of the air traffic stream and
compare them with the answers of MobilityDB that export_baseline.sql writes (positions.csv, the
aircraft and the time in milliseconds of each position report of FlightsPositions, and d1.csv,
the rows of dashboard 1). The topics are read from their beginning to their current end, as
#kafka_reader of chapter9/Flink_Examples/Geofencing/mapserver_geofence.py reads its topic. The
counts are printed and written into <out>/summary.json, beside the dumps of the topics.

    python compare.py <out> [<baseline>]          (default <baseline>: baseline)
"""
import csv
import json
import sys

import duckdb
from kafka import KafkaConsumer, TopicPartition

OUT = sys.argv[1]
BASE = sys.argv[2] if len(sys.argv) > 2 else "baseline"


def stream_rows(topic):
    """The rows of a topic, from its beginning to its current end."""
    c = KafkaConsumer(bootstrap_servers="localhost:9092", enable_auto_commit=False,
                      consumer_timeout_ms=20000, max_poll_records=50000)
    parts = [TopicPartition(topic, p) for p in (c.partitions_for_topic(topic) or [])]
    if not parts:
        return
    c.assign(parts)
    c.seek_to_beginning(*parts)
    end = c.end_offsets(parts)
    done = {tp: c.position(tp) >= end[tp] for tp in parts}
    while not all(done.values()):
        batch = c.poll(timeout_ms=5000)
        for tp, msgs in batch.items():
            for m in msgs:
                yield json.loads(m.value)
                if m.offset + 1 >= end[tp]:
                    done[tp] = True
        if not batch:
            break
    c.close()


def dump(topic):
    return list(stream_rows(topic))


res = {}
# ---------------------------------------------------------------- positions
# The positions are written in the order of the topic to a CSV, which DuckDB compares with the
# baseline, and their lateness is measured against the largest report time already written
lateness_max, late30, late60, n = None, 0, 0, 0
with open(f"{OUT}/positions.csv", "w") as f:
    for r in stream_rows("flights-positions"):
        t = r["pts"]
        if lateness_max is not None:
            if t < lateness_max - 30000:
                late30 += 1
            if t < lateness_max - 60000:
                late60 += 1
        lateness_max = t if lateness_max is None else max(lateness_max, t)
        f.write(f"{r['icao24']},{t}\n")
        n += 1
res["stream_positions"], res["late30"], res["late60"] = n, late30, late60
con = duckdb.connect()
con.execute("SET memory_limit='2GB'; SET threads=4")
con.execute(f"CREATE TABLE s AS SELECT * FROM read_csv('{OUT}/positions.csv', header=false, "
            "columns={'icao24': 'VARCHAR', 'pts': 'BIGINT'})")
con.execute(f"CREATE TABLE b AS SELECT * FROM read_csv('{BASE}/positions.csv', header=false, "
            "columns={'icao24': 'VARCHAR', 'pts': 'BIGINT'})")


def q(sql):
    return con.execute(sql).fetchall()[0][0]


res["stream_duplicates"] = q(
    "SELECT count(*) - (SELECT count(*) FROM (SELECT DISTINCT * FROM s)) FROM s")
res["baseline_positions"] = q("SELECT count(*) FROM b")
res["stream_aircraft"] = q("SELECT count(DISTINCT icao24) FROM s")
res["baseline_aircraft"] = q("SELECT count(DISTINCT icao24) FROM b")
res["positions_only_stream"] = q("SELECT count(*) FROM (SELECT * FROM s EXCEPT SELECT * FROM b)")
res["positions_only_baseline"] = q(
    "SELECT count(*) FROM (SELECT * FROM b EXCEPT SELECT * FROM s)")
con.execute(f"""COPY (
  WITH os AS (SELECT icao24, count(*) n FROM (SELECT * FROM s EXCEPT SELECT * FROM b) GROUP BY 1),
       ob AS (SELECT icao24, count(*) n FROM (SELECT * FROM b EXCEPT SELECT * FROM s) GROUP BY 1)
  SELECT coalesce(os.icao24, ob.icao24) AS icao24, coalesce(os.n, 0) AS only_stream,
    coalesce(ob.n, 0) AS only_baseline
  FROM os FULL JOIN ob ON os.icao24 = ob.icao24 ORDER BY 2 + 3 DESC)
  TO '{OUT}/aircraft_differ.csv' (HEADER)""")
res["aircraft_differ"] = q(f"SELECT count(*) FROM read_csv('{OUT}/aircraft_differ.csv')")
dropped = dump("flights-dropped")
res["dropped_sessions"] = len(dropped)
res["dropped_aircraft"] = len({d["icao24"] for d in dropped})
res["dropped_kept_positions"] = sum(d["kept"] for d in dropped)
json.dump(dropped, open(f"{OUT}/dropped.json", "w"))

# ---------------------------------------------------------------- dashboard 1
d1 = dump("climbing-brussels")
res["d1_rows"] = len(d1)
res["d1_flights"] = len({(r["icao24"], r["callsign"]) for r in d1})
res["d1_aircraft"] = len({r["icao24"] for r in d1})
json.dump(d1, open(f"{OUT}/d1.json", "w"))
b1 = list(csv.DictReader(open(f"{BASE}/d1.csv")))
res["d1_base_rows"] = len(b1)
res["d1_base_flights"] = len({(r["icao24"], r["callsign"]) for r in b1})
res["d1_base_aircraft"] = len({r["icao24"] for r in b1})


def millis_of_day(ts):
    """The milliseconds of the day of a timestamp written by PostgreSQL or by Flink."""
    ts = ts.replace("T", " ").rstrip("Z").split("+")[0]
    hh, mm, ss = ts[11:].split(":")
    return round((int(hh) * 3600 + int(mm) * 60 + float(ss)) * 1000)


bkeys = {(r["icao24"], millis_of_day(r["t"])): r for r in b1}
match, match_xy = 0, 0
for r in d1:
    k = (r["icao24"], millis_of_day(r["posts"]))
    if k in bkeys:
        match += 1
        b = bkeys[k]
        if abs(float(b["lon"]) - r["lon"]) < 1e-9 and abs(float(b["lat"]) - r["lat"]) < 1e-9:
            match_xy += 1
res["d1_rows_in_baseline"], res["d1_rows_in_baseline_same_xy"] = match, match_xy

# ---------------------------------------------------------------- dashboard 2
d2 = dump("close-pairs")
res["d2_pairs"] = len(d2)
res["d2_distinct_pairs"] = len({(r["icao24_1"], r["icao24_2"]) for r in d2})
res["d2_windows"] = len({r["window_start"] for r in d2})
if d2:
    res["d2_closest"] = min(d2, key=lambda r: (r["distance"], r["icao24_1"], r["icao24_2"]))
json.dump(d2, open(f"{OUT}/d2.json", "w"))

# ---------------------------------------------------------------- dashboard 3
d3 = dump("traffic-per-hour")
res["d3_hours"] = len(d3)
res["d3"] = sorted(d3, key=lambda r: r["window_start"])
json.dump(res, open(f"{OUT}/summary.json", "w"), indent=1)
print(json.dumps({k: v for k, v in res.items() if k != "d3"}, indent=1))
for r in res["d3"]:
    print(r)
