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

"""Run the statements of flights_queries.sql, the tables of the five queries of the notebook
8.4 Queries-flights-MobilitySpark, on the YARN cluster, timing each one, then write their
summaries and the rows that the maps draw.

    spark-submit run_queries.py <rounds> <step> ...
    steps: countries q1 q2 q3 q4 q5 export

`statements`, `log`, `query` and `ddl` are those of run_dashboards.py. Step countries builds the
table countries, q1 to q5 the table of each query, printing its summary, and export writes the
rows of the maps, as the last cell of the notebook does. Each answer is written to
$OUT/<name>.csv (default: out/queries below the working directory) and each time to
$OUT/times.tsv."""
import csv, os, re, sys, time

from pyspark.sql import SparkSession

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT", "out/queries")
os.makedirs(OUT, exist_ok=True)
rounds = int(sys.argv[1])
steps = sys.argv[2:]

spark = SparkSession.builder.appName("Flights-Queries") \
    .config("spark.sql.session.timeZone", "UTC").getOrCreate()
jvm = spark._jvm
conf = spark.sparkContext._jsc.hadoopConfiguration()
for t in ("flights", "flightseu", "countries", "morningflights", "brusselsdepartures",
          "countrytraffic", "airbornecount", "holding"):
    path = jvm.org.apache.hadoop.fs.Path(f"/spark-warehouse/{t}")
    fs = path.getFileSystem(conf)
    if fs.exists(jvm.org.apache.hadoop.fs.Path(f"/spark-warehouse/{t}/_delta_log")):
        spark.sql(f"CREATE TABLE IF NOT EXISTS {t} USING DELTA LOCATION '/spark-warehouse/{t}'")
    else:
        fs.delete(path, True)


def statements():
    with open(os.path.join(HERE, "flights_queries.sql")) as f:
        text = re.sub(r"/\*.*?\*/", "", f.read(), flags=re.S)
    lines = [ln for ln in text.splitlines() if not ln.lstrip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def log(name, rnd, secs, info):
    with open(os.path.join(OUT, "times.tsv"), "a") as f:
        f.write(f"{time.strftime('%H:%M:%S')}\t{name}\t{rnd}\t{secs:.1f}\t{info}\n")
    print(f"TIME {name} round {rnd}: {secs:.1f} s  {info}", flush=True)


def query(name, sql, rnd=1):
    t0 = time.time()
    rows = spark.sql(sql).collect()
    secs = time.time() - t0
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
        # the folder of a table is its name in lower case
        if s.upper().startswith("DROP TABLE IF EXISTS "):
            path = jvm.org.apache.hadoop.fs.Path("/spark-warehouse/" + s.split()[-1].lower())
            path.getFileSystem(conf).delete(path, True)
    secs = time.time() - t0
    log(name, rnd, secs, spark.sql(check).collect()[0])


S = statements()   # view, drop/create countries, drop/create x 5 queries
for rnd in range(1, rounds + 1):
    for step in steps:
        if step == "countries":
            ddl("countries", S[0:3], rnd, "SELECT count(*) FROM Countries")
        elif step == "q1":
            ddl("q1", S[3:5], rnd, "SELECT count(*), count(DISTINCT ICAO24), "
                "sum(geoLength(Trip)) / 1000 FROM MorningFlights")
        elif step == "q2":
            ddl("q2", S[5:7], rnd, "SELECT count(*), count(DISTINCT ICAO24), sum(Km) "
                "FROM BrusselsDepartures")
        elif step == "q3":
            ddl("q3", S[7:9], rnd, "SELECT count(*), sum(Flights), sum(Km) "
                "FROM CountryTraffic")
        elif step == "q4":
            ddl("q4", S[9:11], rnd, "SELECT numInstants(Aircraft), maxValue(Aircraft), "
                "twAvg(Aircraft) FROM AirborneCount")
        elif step == "q5":
            ddl("q5", S[11:13], rnd, "SELECT count(*), count(DISTINCT ICAO24), "
                "sum(geoLength(Trip)) / 1000 FROM Holding")
        elif step == "export":
            query("q1_rows", "SELECT ICAO24, CallSign, geoLength(Trip) AS Length, "
                  "ST_AsText(ST_GeomFromEWKB(unhex(asHexEWKB(trajectory(geoTransform(Trip, 4326)))))) AS WKT FROM MorningFlights")
            query("q2_rows", "SELECT ICAO24, CallSign, Km, ST_AsText(ST_GeomFromEWKB(unhex(asHexEWKB(Route)))) AS WKT, "
                  "ST_AsText(ST_GeomFromEWKB(unhex(asHexEWKB(Destination)))) AS Destination FROM BrusselsDepartures")
            query("q3_rows", "SELECT Name, Flights, Km FROM CountryTraffic ORDER BY Name")
            query("q4_rows", "SELECT numInstants(Aircraft) AS Instants, maxValue(Aircraft) AS Peak, "
                  "startTimestamp(atValue(Aircraft, maxValue(Aircraft))) AS PeakTime, "
                  "twAvg(Aircraft) AS Average FROM AirborneCount")
            query("q4_hours", "SELECT h AS Hour, valueAtTimestamp(Aircraft, h) AS Aircraft "
                  "FROM AirborneCount LATERAL VIEW explode(sequence(timestamp '2026-03-01 00:00:00', "
                  "timestamp '2026-03-01 23:00:00', interval 1 hour)) AS h ORDER BY h")
            query("q4_series", "SELECT asText(Aircraft) AS Aircraft FROM AirborneCount")
            query("q5_rows", "SELECT Fix, ICAO24, CallSign, CAST(duration(Trip) AS STRING) AS Holding, "
                  "geoLength(Trip) / 1000 AS Km, "
                  "ST_AsText(ST_GeomFromEWKB(unhex(asHexEWKB(trajectory(Trip))))) AS WKT "
                  "FROM Holding ORDER BY Fix, ICAO24, CallSign")
spark.stop()
