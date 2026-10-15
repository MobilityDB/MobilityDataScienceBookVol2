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

