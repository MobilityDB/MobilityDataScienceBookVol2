## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

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
