## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### The Flights Data of the Book

The chapters on large-scale processing (Apache Spark with MobilitySpark) and on stream processing
(Apache Flink with MobilityFlink) use air traffic data: the state vectors that the
[OpenSky Network](https://opensky-network.org/) publishes for Sunday, March 1, 2026, as a sample of
the table `state_vectors` of its historical database. The first volume of the book studied June 1,
2020 in MobilityDB; the notebook
`chapter8/8.3 Create tables from scratch-flights-MobilitySpark.ipynb` builds the same tables in
Spark. The appendix "The Flights Data of the Book" describes the data and the rules.

### Tables

| Name | Content |
|---|---|
| `flightsinput` | The state vectors that have a squawk, of the aircraft that report a position, with their timestamps and their point |
| `flightsday` | One row per aircraft, its day as a `tgeogpoint` and as temporal velocity, heading, vertical rate, call sign, alert, and altitude |
| `flights` | One row per aircraft and call sign, the attributes of `flightsday` restricted to the periods of the call sign |

### Software

- Apache Spark 4.0 with Apache Sedona 1.8.0 and Delta Lake 4.0.0, as for the Citi Bike data.
- MobilitySpark, its JMEOS jar and `libmeos.so`, built as in `chapter8/Dockerfile.leti`.
- curl.

### Building the data

    bash fetch_data.sh

downloads the 24 Parquet files of the day, one per hour (13 GB), into
`data/flights/parquet/hour=<Unix time of the hour>/`. The files hold one state vector per aircraft
and per second; the notebook keeps those at every tenth second, the time step of the public samples
of OpenSky, 69,442,890 of the 695,706,186 state vectors of the day. The notebook reads the files
from `/opt/data/flights/parquet`. On a laptop it takes about ten minutes, and prints:

| | |
|---|---|
| State vectors kept | 34,067,894 |
| Aircraft | 29,395 |
| Instants of the trajectories | 29,431,717 |
| Flights | 68,371 |
| Call signs | 65,007 |
