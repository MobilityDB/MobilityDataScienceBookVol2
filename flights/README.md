## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### The Flights Data of the Book

The chapters on large-scale processing (Apache Spark with MobilitySpark) and on stream processing
(Apache Flink with MobilityFlink) use air traffic data: the state vectors that the
[OpenSky Network](https://opensky-network.org/) publishes for Monday, June 27, 2022, the last day of
its public samples. The first volume of the book studied June 1, 2020 in MobilityDB; the notebook
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
- curl and tar.

### Building the data

    bash fetch_data.sh

downloads the 24 archives of the day (3.6 GB) into `data/flights/tar/` and unpacks their gzipped
CSV files (3.6 GB) into `data/flights/csv/`. The variable `DAY` chooses another Monday of the
samples. The notebook reads the files from `/opt/data/flights/csv`. On a laptop it takes about nine
minutes, and prints:

| | |
|---|---|
| State vectors kept | 32,757,265 |
| Aircraft | 25,785 |
| Instants of the trajectories | 29,170,886 |
| Flights | 62,591 |
| Call signs | 59,550 |
