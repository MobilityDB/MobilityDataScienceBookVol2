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

"""Run the tables and the queries of the three flights dashboards of chapter 8 on the YARN
cluster, as the book prints them (the files of chapter8/dashboards), timing each one.

    spark-submit run_dashboards.py <rounds> <step> ...
    steps: tables closepair d1 d2 d3 d3rows flightseu

The tables of the notebook 8.3 and of dashboards_tables.sql are registered from their Delta
locations in /spark-warehouse. `statements` splits a file of chapter8/dashboards into its
statements, as app.py does; `query` runs one statement and writes its rows, `ddl` runs the drop
and the creation of a table and prints its size. Step tables builds flightseu, flightseu3d and
airborne3d, closepair the closest pair, d1 and d2 the panels of dashboards 1 and 2, d3 the
summary (positions, aircraft, average altitude) of the two panels of dashboard 3 and d3rows
their rows. The statements are read from $DASHBOARDS (default: the directory dashboards beside
this one); each answer is written to $OUT/<name>.csv (default: out/dashboards below the working
directory) and each time to $OUT/times.tsv."""
import csv, os, sys, time

from pyspark.sql import SparkSession

D = os.environ.get("DASHBOARDS",
                   os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dashboards"))
OUT = os.environ.get("OUT", "out/dashboards")
os.makedirs(OUT, exist_ok=True)
rounds = int(sys.argv[1])
steps = sys.argv[2:]

spark = SparkSession.builder.appName("Flights-Dashboards") \
    .config("spark.sql.session.timeZone", "UTC").getOrCreate()
print("executors", spark.sparkContext.getConf().get("spark.executor.instances"),
      spark.sparkContext.getConf().get("spark.executor.cores"),
      spark.sparkContext.getConf().get("spark.executor.memory"), flush=True)
jvm = spark._jvm
conf = spark.sparkContext._jsc.hadoopConfiguration()
for t in ("flightsinput", "flightspositions", "flightsday", "flights", "flightseu",
          "flightseu3d", "airborne3d", "closepair"):
    path = jvm.org.apache.hadoop.fs.Path(f"/spark-warehouse/{t}")
    fs = path.getFileSystem(conf)
    if fs.exists(jvm.org.apache.hadoop.fs.Path(f"/spark-warehouse/{t}/_delta_log")):
        spark.sql(f"CREATE TABLE IF NOT EXISTS {t} USING DELTA LOCATION '/spark-warehouse/{t}'")
    else:  # a dashboard table not built yet: no folder left for its CREATE TABLE AS
        fs.delete(path, True)
        print("no table", t, flush=True)


def statements(name):
    with open(os.path.join(D, name)) as f:
        lines = [ln for ln in f.read().splitlines() if not ln.lstrip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def log(name, rnd, secs, info):
    with open(os.path.join(OUT, "times.tsv"), "a") as f:
        f.write(f"{time.strftime('%H:%M:%S')}\t{name}\t{rnd}\t{secs:.1f}\t{info}\n")
    print(f"TIME {name} round {rnd}: {secs:.1f} s  {info}", flush=True)


def query(name, sql, rnd):
    t0 = time.time()
    rows = spark.sql(sql).collect()
    secs = time.time() - t0
    if rnd == 1:
        with open(os.path.join(OUT, name + ".csv"), "w", newline="") as f:
            w = csv.writer(f)
            if rows:
                w.writerow(rows[0].__fields__)
            for r in rows:
                w.writerow(["" if v is None else v for v in r])
    log(name, rnd, secs, f"{len(rows)} rows")
    return rows


def ddl(name, stmts, rnd, check):
    t0 = time.time()
    for s in stmts:
        spark.sql(s).collect()
        # as cell 4 of the notebook; the folder of a table is its name in lower case
        if s.upper().startswith("DROP TABLE IF EXISTS "):
            path = jvm.org.apache.hadoop.fs.Path("/spark-warehouse/" + s.split()[-1].lower())
            path.getFileSystem(conf).delete(path, True)
    secs = time.time() - t0
    log(name, rnd, secs, spark.sql(check).collect()[0][0])


T = statements("dashboards_tables.sql")    # drop/create x 4, then SELECT * FROM closepair
summary3 = ("SELECT COUNT(*) AS Positions, COUNT(DISTINCT ICAO24) AS Aircraft, "
            "AVG(Altitude) AS Altitude FROM ({}) q")
for rnd in range(1, rounds + 1):
    for step in steps:
        if step == "flightseu":
            ddl("flightseu", T[0:2], rnd, "SELECT count(*) FROM FlightsEU")
        elif step == "tables":
            ddl("flightseu", T[0:2], rnd, "SELECT count(*) FROM FlightsEU")
            ddl("flightseu3d", T[2:4], rnd, "SELECT count(*) FROM FlightsEU3D")
            ddl("airborne3d", T[4:6], rnd, "SELECT count(*) FROM Airborne3D")
        elif step == "closepair":
            ddl("closepair", T[6:8], rnd, "SELECT concat_ws(' ', *) FROM ClosePair")
        elif step == "d1":
            query("d1", statements("dashboard1.sql")[0], rnd)
        elif step == "d2":
            for i, n in enumerate(["d2_distance", "d2_positions", "d2_altitude1",
                                   "d2_altitude2"]):
                query(n, statements("dashboard2.sql")[i], rnd)
        elif step == "d3":
            d3 = statements("dashboard3.sql")
            query("d3_positions", summary3.format(d3[0]), rnd)
            query("d3_cruising", summary3.format(d3[1]), rnd)
        elif step == "d3rows":
            d3 = statements("dashboard3.sql")
            query("d3_positions_rows", d3[0], rnd)
            query("d3_cruising_rows", d3[1], rnd)
spark.stop()
