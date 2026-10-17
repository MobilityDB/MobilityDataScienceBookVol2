## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

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
| `flightspositions` | The position reports, once each at the time of the report, that the aircraft could reach from the report kept before |
| `flightsday` | One row per aircraft, its day as a `tgeogpoint` and as temporal velocity, heading, vertical rate, call sign, alert, and altitude |
| `flights` | One row per aircraft and call sign, the attributes of `flightsday` restricted to the periods of the call sign |

### Software

- Apache Spark 4.0 with Apache Sedona 1.8.0 and Delta Lake 4.0.0, as for the Citi Bike data.
- MobilitySpark, its JMEOS jar and `libmeos.so`, built as in `chapter8/Dockerfile.leti`.
- For `build.sh`: PostgreSQL 18 with PostGIS 3.6 (and its `shp2pgsql`) and MobilityDB 1.4, and
  the DuckDB shell 1.5.
- curl and unzip.

### Building the data

    bash fetch_data.sh

downloads the 24 Parquet files of the day, one per hour (13 GB), into
`data/flights/parquet/hour=<Unix time of the hour>/`. The files hold one state vector per aircraft
and per second; the notebook keeps those at every tenth second, the time step of the public samples
of OpenSky, 69,442,890 of the 695,706,186 state vectors of the day. The notebook reads the files
from `/opt/data/flights/parquet`. On the cluster of the chapter it takes about 15 minutes, and
prints:

| Item | Count |
|---|--:|
| State vectors kept | 34,067,894 |
| Aircraft | 29,395 |
| Position reports | 27,812,444 |
| Position reports kept by the walk | 27,226,708, of 29,182 aircraft |
| Instants of the trajectories | 27,194,486 |
| Flights | 68,371, of 29,252 aircraft |
| Call signs | 65,007, the empty one of 219 flights included |

### Building the data in MobilityDB

    bash fetch_data.sh
    bash build.sh

`build.sh` builds the same four tables in the PostgreSQL database `$PGDATABASE` (default:
`flights`), with PostgreSQL 18, PostGIS 3.6 and MobilityDB 1.4, and the DuckDB shell 1.5 named by
the variable `DUCKDB`. `flights_load.sql` creates the table `FlightsInputRaw`, DuckDB reads each
Parquet file and hands over the state vectors at every tenth second, and `flights_build.sql`
follows the script `opensky_input.sql` of chapter 5 of the first volume, with the column types and
the trimmed call sign of the notebook, and with the two rules of the appendix: the trajectory takes
one point per position report, at the time of the report, and the walk keeps the reports that the
aircraft could reach at 400 m/s from the report kept before. The answers of MobilityDB are those that
MobilitySpark and MobilityFlink reproduce. It takes about 48 minutes, and prints the same figures as
the notebook.

### The dashboards in MobilityDB

    bash run_all.sh

runs `flights_dashboards.sql`, the tables and the queries of the three dashboards of chapter 8, on
the database that `build.sh` builds, writes its output to `out/flights_dashboards.out`, and compares
the number of rows of each answer with `expected/flights_dashboards.rows`, those of the run of
MobilityDB whose answers the notebooks of MobilitySpark and MobilityFlink reproduce. It takes about
nine minutes.

### The queries in MobilityDB

    bash run_all.sh flights_queries

runs `flights_queries.sql`, the queries of the analysis of the flights of chapter 8 that the
notebook `chapter8/8.4 Queries-flights-MobilitySpark.ipynb` runs in Spark: the flights over
Europe between 8 and 9 o'clock, the flights leaving Brussels, the flights over each country of
Natural Earth with the distance they fly there, the number of aircraft in the air over Europe at
each instant of the day, and the time that each flight spends within 15 km of each holding fix of
London Heathrow, measured on the WGS 84 spheroid. `fetch_data.sh` downloads the countries, the
shapefile `ne_50m_admin_0_countries` at the scale 1:50m, into `data/flights/countries/`, and
`build.sh` loads them into the table `CountriesInput` with `shp2pgsql` of PostGIS. The rows of
the five answers are written into `out/flights_queries_q<n>.csv`. It takes about six minutes.

### The baseline of the stream queries in MobilityDB

    bash run_all.sh flights_stream_queries

runs `flights_stream_queries.sql`, the trajectories that the job
`chapter9/Flink_Examples/flights_stream/flights_queries.py` builds from the stream in MobilityFlink,
built in MobilityDB from the reports of `FlightsPositions`: the trajectory of each aircraft over
the envelope of Europe per hour; the flights that end at Brussels, a flight being the reports of
an aircraft until a silence of one hour; the number of aircraft in the air over Europe at each
instant of each hour; and the time that each flight spends within 15 km of each holding fix of
London Heathrow. The velocity and the call sign of each report are read from the first state
vector that carries it, as the walk of the stream reads them. The rows of the four answers are
written into `out/flights_stream_queries_q<n>.csv`. It takes about eleven minutes.
