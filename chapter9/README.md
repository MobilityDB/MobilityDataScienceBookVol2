## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 9: Mobility Streams

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The examples of the chapter process the Citi Bike trips of September 20, 2023 with Apache Flink,
reading them either from a file or from Apache Kafka, where a producer replays them as a stream of
events. The files are exported by the pipeline of the directory `citibike` of this repository,
described in the appendix "The Citi Bike Data of the Book"; build them first.

### Software

- Python 3.12 with `apache-flink` 2.1.0 (PyFlink), `kafka-python`, and `flask`:

      pip install apache-flink==2.1.0 kafka-python flask

- The Kafka SQL connector of Flink, copied into the `lib` directory of PyFlink:

      L=$(python -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
      curl -fL -o $L/flink-sql-connector-kafka-4.0.1-2.0.jar \
        https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/4.0.1-2.0/flink-sql-connector-kafka-4.0.1-2.0.jar

- A Kafka broker on `localhost:9092`, for instance in Docker:

      docker run -d --name kafka -p 9092:9092 apache/kafka:3.9.1

### Running the examples

Every script reads `data/citibike/flink/`, so run them from the directory that holds `data/`
(the root of this repository, or a directory where `data` is linked). The scripts are in
`Flink_Examples/`:

| Example of the chapter | Scripts |
|---|---|
| Stateful aggregation | `Introductory_examples/stateful_agg.py` |
| Tumble window aggregation | `Introductory_examples/tumblewin_eventtime.py` |
| Sliding window aggregation | `replay_trips.py`, `Introductory_examples/slidingwin_event_time.py` |
| Cumulative window aggregation | `replay_trips.py`, `Introductory_examples/cumulatewin-event-kafka.py` |
| Joining streams | `join_two_streams/producerstationstart.py`, `join_two_streams/producerstationend.py`, `join_two_streams/stationbalance.py`, `join_two_streams/mapserver-stationbalance.py` (http://localhost:5050) |
| Top ten stations | `replay_trips.py`, `TopNSlideWEventTime/topneventsliding.py`, `TopNSlideWEventTime/mapservertopn.py` (http://localhost:5000) |
| Borough occupation | `replay_trips.py`, `borough_occup_tumbling/boroughoccupationevent.py`, `borough_occup_tumbling/mapserverboro.py` (http://localhost:5001) |
| Geofencing | `replay_trips.py`, `Geofencing/flink_eventtime_geofence.py`, `Geofencing/mapserver_geofence.py` (http://localhost:8888) |

`Introductory_examples/stateful_agg_kafka.py`, `tumblewin_proctime.py` and
`tumblewin_proctime_nokafka.py` are variants of the first two examples, which write to Kafka or
use processing time.

For an example that reads Kafka, create its input topics, start the Flink job, then the map
server, and finally the producer:

    docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
      --create --if-not-exists --topic raw-trips
    python Flink_Examples/TopNSlideWEventTime/topneventsliding.py &
    python Flink_Examples/TopNSlideWEventTime/mapservertopn.py &
    python Flink_Examples/replay_trips.py 2000

The producers replay the day at 2000 times its real speed by default, so that the morning peak
arrives after about 15 seconds; a different speed-up factor is their first argument. The join
example reads the topics `trip-starts` and `trip-ends`, written by its two producers.

### Air traffic over Europe as a stream

The use case "Air Traffic over Europe as a Stream" replays the state vectors of March 1, 2026 of
the OpenSky Network, which `flights/fetch_data.sh` downloads into `data/flights/parquet/`, and
expresses the three dashboards of the air traffic use case of chapter 8 as continuous queries of
MobilityFlink. Its code is in `Flink_Examples/flights_stream/`:

| Step | Code |
|---|---|
| Replay of the state vectors into the topic `flights-states` | `replay_flights.py` |
| Position and reachability rules, into the topic `flights-positions` | `walk/` (the Java job `flights.FlightsWalk`) |
| The three dashboards, into the topics `climbing-brussels`, `close-pairs` and `traffic-per-hour` | `flights_dashboards.py` |
| The dashboards, a Streamlit application reading these topics | `app.py` (http://localhost:8501) |
| The trajectories of the stream, into the topics `hourly-trips`, `brussels-arrivals`, `airborne-hourly` and `holding` | `flights_queries.py` |

It needs, besides the software above, `duckdb`, `confluent-kafka`, `streamlit` 1.65.0 and
`pydeck`, a JDK 21 with Maven, and MobilityFlink, which brings the functions of MEOS into Flink:
its script `tools/refresh-from-master.sh` builds `libmeos.so` from MobilityDB and the jar of
JMEOS, and `mvn install` in its repository installs the jars of JMEOS and MobilityFlink in the
local Maven repository. The job of the walk is then built by

    pip install duckdb confluent-kafka streamlit==1.65.0 pydeck
    (cd Flink_Examples/flights_stream/walk && mvn package)

which also copies MobilityFlink, JMEOS and their dependencies into `walk/target/lib/`. The
dashboards job loads them with `LOAD MODULE mobilitydb`, from the jars that the variable
`MOBILITYFLINK_JARS` lists, and JMEOS loads `libmeos.so` from the library path of the system,
which `LD_LIBRARY_PATH` sets to the directory of the `libmeos.so` that MobilityFlink built. Create
the topics, start the two jobs and the application, and finally the producer, from the directory
that holds `data/`:

    for t in flights-states flights-positions flights-dropped climbing-brussels close-pairs \
        traffic-per-hour hourly-trips brussels-arrivals airborne-hourly holding; do
      docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
        --create --if-not-exists --topic $t
    done
    export LD_LIBRARY_PATH=<directory of libmeos.so>
    W=Flink_Examples/flights_stream
    export MOBILITYFLINK_JARS=$(ls $W/walk/target/lib/*.jar | paste -sd ';')
    PYLIB=$(python -c "import pyflink, os; print(os.path.dirname(pyflink.__file__))")/lib
    java -Xmx1200m -cp "$PYLIB/*:$W/walk/target/flights-walk-1.0.jar:$W/walk/target/lib/*" \
      flights.FlightsWalk &
    python $W/flights_dashboards.py &
    python $W/flights_queries.py &
    (cd $W && streamlit run app.py --server.enableStaticServing true --theme.base light) &
    python $W/replay_flights.py

The producer replays the day at 20 times its real speed by default, so that the replay of the day
takes 76 minutes; a different speed-up factor is its first argument, and a factor of 1e12
replays it as fast as the producer sends, in less than four minutes. Given the argument `bounded`,
the jobs read their input topic up to its current end and stop, so that, run after the replay,
they answer over the whole day.

### Measurements of the air traffic stream

The directory `Flink_Examples/flights_stream/measure` holds the scripts that measure and compare
the answers of the stream that the use case states, with the setup above. Each session starts its
own Kafka broker in the Docker container `flights-kafka` on port 9092, so that no other broker
may run there, replays the day at full speed, runs the
jobs bounded over the topics up to their end, timing each, and stops the broker; it runs from the
directory that holds `data/` and `src/libmeos.so`, with `MEOS_LIB` the directory of that
`libmeos.so` and `PYTHON` the Python with the packages above:

- `report_delay.sql` counts with DuckDB the position reports of the Parquet day, the delay
  between the time of a report and the first state vector that carries it, the reports that
  arrive after a later report of their aircraft, and their lateness:
  `DATA=data duckdb < $W/measure/report_delay.sql`.
- `export_baseline.sql` writes into the working directory the answers of MobilityDB that
  `compare.py` reads, the position reports of `FlightsPositions` and the rows of dashboard 1,
  from the database that `flights/build.sh` and `flights/run_all.sh` build.
- `dashboards_session.sh <out>` runs the walk and `flights_dashboards.py`, and `compare.py` then
  dumps their topics into `<out>` and compares the positions and the rows of dashboard 1 with
  those of MobilityDB in `$BASELINE` (default: `baseline`), writing `<out>/summary.json`.
- `queries_session.sh <out>` runs the walk and `flights_queries.py` and dumps the topics
  `hourly-trips`, `brussels-arrivals`, `airborne-hourly` and `holding` into `<out>`;
  `compare_queries.py <out> <flights/out>` compares the last two with the answers of
  `flights/flights_stream_queries.sql`, and `chapter8/figures/flights_stream_maps.py` draws the
  maps of the first two.

For instance, with `W=Flink_Examples/flights_stream` as above:

    mkdir -p baseline && (cd baseline && psql -d flights -f ../$W/measure/export_baseline.sql)
    MEOS_LIB=<directory of libmeos.so> bash $W/measure/dashboards_session.sh out/dashboards
    MEOS_LIB=<directory of libmeos.so> bash $W/measure/queries_session.sh out/queries

### Figures

The directory `figures` holds the scripts that print the dashboards of the chapter to the PDF
files of its figures, with `capture.py`, which opens a page in the Chromium of Playwright
(`pip install playwright && playwright install chromium`) and prints it once a condition holds
in the page and the basemap has settled, at the printed width of the figure and with the
basemap at 300 dpi. `citibike_dashboards.sh` runs the Kafka broker, the Flink job, the map
server and the producers of each Citi Bike example as above, over the trips of the day up to the
instant that the figure shows, and prints the page; `flights_dashboards.sh <out> [<hour>]` runs
the walk, the dashboards job and the Streamlit application while the day is replayed at its
default speed-up, and prints the page once the dashboards show the given hour (default: 10). Run
them from the directory that holds `data/`, here the directory `chapter9` with `data` linked in
it:

    bash figures/citibike_dashboards.sh top10 geofence boro slidejoin
    MEOS_LIB=<directory of libmeos.so> bash figures/flights_dashboards.sh out

| Figure | Script, output |
|---|---|
| Top ten stations in a sliding window | `citibike_dashboards.sh top10`, `out/top10.pdf` |
| Geofencing | `citibike_dashboards.sh geofence`, `out/geofence.pdf` |
| Borough occupation | `citibike_dashboards.sh boro`, `out/boro.pdf` |
| Joining streams: the balance of the stations | `citibike_dashboards.sh slidejoin`, `out/slidejoin.pdf` |
| The dashboards of the air traffic stream | `flights_dashboards.sh`, `out/flightsStreamDashboards.pdf` |
