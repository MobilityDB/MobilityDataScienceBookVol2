## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### The Citi Bike Data of the Book

The chapters on large-scale processing (Apache Spark and Apache Sedona) and on stream processing
(Apache Kafka and Apache Flink) use the same data: the trips of the bicycle sharing system Citi
Bike in New York City during 2023. The scripts of this directory build the tables of the chapter
on Spark, by the statements of its section "The Citi Bike Data", and export from them the files
that the examples of the chapter on Flink replay. The appendix "The Citi Bike Data of the Book"
describes the data and the rules.

### Tables and files

| Name | Content |
|---|---|
| `trips` | The trips that have a position of departure and of arrival, with the 13 columns of the files, the points `origin` and `target`, and `duration_ms`; the station identifiers are cleaned |
| `nta` | The 2020 Neighborhood Tabulation Areas of New York City, release 26b, in EPSG:4326 |
| `stations` | One row per station, at the average position of its trips, with its borough and its NTA |
| `station_duplicates` | The identifiers of the same station merged into the one with more trips |
| `boroughs` | The boundary of each borough, as the union of its NTAs |
| `flink/trips` | The trips that start on September 20, 2023, in the order of their start (tab-separated, no header) |
| `flink/stations` | The stations, with their longitude, latitude, borough, NTA code and name, and geometry (tab-separated, no header) |

### Software

- Java 17 or 21, and Apache Spark 4.0.1 (`spark-4.0.1-bin-hadoop3`), named by the variable
  `SPARK_HOME`. At its first start, Spark downloads Apache Sedona 1.8.0 and Delta Lake 4.0.0
  from Maven Central.
- curl and unzip.

### Building the data

    bash fetch_data.sh
    SPARK_HOME=/path/to/spark-4.0.1-bin-hadoop3 bash build.sh

`fetch_data.sh` downloads the archive of 2023 (1.6 GB) and the NTAs into `data/citibike/`, and
unpacks the monthly archives (6.4 GB) and the 40 CSV files of the trips (6.4 GB); with the Delta
tables (5.2 GB), the data take about 20 GB. Nothing is redistributed in this repository:
each file comes from its publisher. `build.sh` runs `citibike_build.sql`, which builds the Delta
tables in `data/citibike/warehouse/`, and `export_flink.sql`, which writes the two files into
`data/citibike/flink/`. The variable `DAY` chooses another day for the export. On a laptop, the
whole pipeline takes about six minutes, and prints:

| Item | Count |
|---|--:|
| Trips | 35,002,469 |
| Stations | 2,266 |
| Stations in an NTA | 2,181 |
| Duplicate identifiers | 2 |
| NTAs | 262 |
| Boroughs | 5 |
| Trips of 2023-09-20 | 155,694 |

The chapter on stream processing reads the exported files from `data/citibike/flink/`: run its
examples from the directory that holds `data/`, or link `data` there.
