## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 7: In-memory Mobility Databases

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

### DuckDB and MobilityDuck

The notebooks `mobilityDuckAIS.ipynb` and `hanoi-book.ipynb` run on DuckDB v1.5.5,
the version against which the continuous integration of
[MobilityDuck](https://github.com/MobilityDB/MobilityDuck) builds and tests the extension.
The extension loads only into the DuckDB version of its build.

1. Install the DuckDB Python client of that version: `pip install duckdb==1.5.5`.
2. Obtain the extension `mobilityduck.duckdb_extension` for your platform, either from the
   artifacts of the latest successful run of the
   [Main Extension Distribution Pipeline](https://github.com/MobilityDB/MobilityDuck/actions/workflows/MainDistributionPipeline.yml)
   on the `main` branch, or by building MobilityDuck as its README explains. Set
   `MOBILITYDUCK_EXTENSION` in the first cells of the notebooks to its path.
3. The extension is not signed by DuckDB, so the notebooks open DuckDB with
   `allow_unsigned_extensions` (in the DuckDB shell, start it with `duckdb -unsigned`).
4. The notebooks install the spatial extension from the `core_nightly` repository
   (`INSTALL spatial FROM core_nightly`). The optimizer of the spatial extension that
   DuckDB v1.5.5 distributes rewrites the `&&` operator as a spatial join even when its
   operands are not geometries, so that queries such as the join of trips and time bins of
   the Hanoi notebook fail with it; the spatial extension of `core_nightly` keeps that
   rewrite to geometries.

### BerlinMOD Data Generator

These files create the BerlinMOD benchmark for the city of Hanoi, based on the hanoi.osm file that can be obtained from OpenStreetMap. To produce the database you shoul follow the step next.

--------------------------
Create the database hanoi_sf0.05 (or your database name)

CREATE EXTENSION MobilityDB Cascade;
create extension pgrouting;
create extension hstore;

osm2pgrouting -h localhost -p 5432 -U postgres -W postgres -f brussels.osm --dbname brussels_sf0.1 -c mapconfig.xml

osm2pgsql   -P 5432 -H localhost -d hanoi_sf0.05 -c -U postgres -W --proj=3857 hanoi.osm

psql -d hanoi_sf0.05 -p 5432 (or your port) -h localhost

 \i hanoi_preparedata.sql
 \i hanoi_datagenerator.sql
 
 select hanoi_datagenerator(0.05);

----------------------------------------

### Timings

The folder `timing` runs the queries whose times the chapter compares: those of the section
"Querying DuckDB" in DuckDB with the spatial extension and in PostgreSQL with PostGIS (`ais`),
those of the AIS use case of MobilityDuck in MobilityDuck and in MobilityDB (`ships`), and those
of the BerlinMOD-Hanoi use case in MobilityDuck and in MobilityDB (`hanoi`). `bench.py` runs
each query three times in each engine, alternately, and records for each run the second of two
consecutive executions, or the only execution of the queries marked `once` in `spec.json`; it
prints how many times longer PostgreSQL took than DuckDB in each round. DuckDB runs the AIS
queries with all the cores of the machine, and MobilityDuck the other queries with one thread.

1. Build the AIS database of the book with the scripts of the folder `ais` of this repository,
   in the PostgreSQL database `ais`, and add to its table `AISInput` the point geometry `Geom`:
   `psql -d ais -f timing/ais/aisinput_pg.sql`.
2. In `timing/ais`, with the file `aisdk-2026-01-20.csv` unzipped there, create the DuckDB
   database of the section: `duckdb ais.duckdb < aisinput_duckdb.sql`.
3. In `timing/ships`, copy the table `Ships` into MobilityDuck,
   `PGDATABASE=ais duckdb -unsigned ships.duckdb < ships_duckdb.sql`, then write the ships of
   the reservoir samples of DuckDB into PostgreSQL: `PGDATABASE=ais bash ships_sample.sh`.
4. Restore into the PostgreSQL database `hanoi` the data set that the
   [BerlinMOD-Hanoi](https://github.com/MobilityDB/MobilityDB-BerlinMOD-Hanoi) repository
   publishes for a scale factor of 0.01, create its table `Bins` and its view `Trips200`,
   `psql -d hanoi -f timing/hanoi/hanoi_pg.sql`, and, in `timing/hanoi`, copy it into
   MobilityDuck: `PGDATABASE=hanoi duckdb -unsigned hanoi.duckdb < hanoi_duckdb.sql`.
5. Run the timings, for instance `python3 bench.py ais/spec.json ais.json` in `timing`, and
   likewise with `ships/spec.json` and `hanoi/spec.json`. `DUCKDB` names the DuckDB shell and
   `PSQL` names psql; when the shell does not carry MobilityDuck, `MOBILITYDUCK_EXTENSION` names
   the file of the extension, which steps 3 and 4 then load with
   `LOAD spatial; LOAD '/path/to/mobilityduck.duckdb_extension';` before the script. The usual
   libpq variables (`PGHOST`, `PGPORT`, `PGUSER`) select the PostgreSQL server.

The queries of `ships` and `hanoi` are written by `make_queries.py`, which holds the listings
of the chapter: `mN.sql` and `hN.sql` are the MobilityDuck queries as the chapter prints them,
and `pg_mN.sql` and `pg_hN.sql` their MobilityDB twins. The AIS queries `qN.sql` name the
spherical distance `ST_DISTFN`, which `bench.py` replaces by `ST_Distance_Sphere` in DuckDB and
by `ST_DistanceSphere` in PostGIS.
