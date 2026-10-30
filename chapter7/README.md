## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 7: In-memory Mobility Databases

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

### DuckDB and MobilityDuck

The notebooks `mobilityDuckAIS.ipynb` and `hanoi-book.ipynb` run on DuckDB v1.5.6,
the version against which the continuous integration of
[MobilityDuck](https://github.com/MobilityDB/MobilityDuck) builds and tests the extension.
The extension loads only into the DuckDB version of its build.

1. Install the DuckDB Python client of that version: `pip install duckdb==1.5.6`. To run the
   notebooks from the command line, as `notebook/run_notebook.py` does, install their kernel and
   runner too: `pip install nbclient ipykernel`.
2. Obtain the extension `mobilityduck.duckdb_extension` for your platform, either from the
   artifacts of the latest successful run of the
   [Main Extension Distribution Pipeline](https://github.com/MobilityDB/MobilityDuck/actions/workflows/MainDistributionPipeline.yml)
   on the `main` branch, or by building MobilityDuck as its README explains. Both notebooks are
   written from the chapter and read from the environment the variables of the section on
   reproducing the chapter below: `mobilityDuckAIS.ipynb` holds every listing of the chapter that
   reads the AIS data and reads `MOBILITYDUCK_EXTENSION`, `AIS_DIR` and `PG_AIS`;
   `hanoi-book.ipynb` holds every SQL listing of the section "BerlinMOD Hanoi", after a first cell
   that reads the Hanoi tables from PostgreSQL with `load/hanoi_duckdb.sql`, and reads
   `MOBILITYDUCK_EXTENSION` and `PG_HANOI`. Both are in the order of the chapter.
   The folder `notebook` writes them from the chapter and runs them: `listings.py` reads the
   listings of `chapter7.tex` that a notebook runs, `build_notebook.py` makes one cell of each,
   and `run_notebook.py` executes the notebook in place, with the variables above set:

       python3 notebook/listings.py chapter7.tex ais ais_listings.json
       python3 notebook/build_notebook.py ais ais_listings.json mobilityDuckAIS.ipynb
       python notebook/run_notebook.py mobilityDuckAIS.ipynb mobilityDuckAIS.ipynb
       python3 notebook/listings.py chapter7.tex hanoi hanoi_listings.json
       python3 notebook/build_notebook.py hanoi hanoi_listings.json hanoi-book.ipynb
       python notebook/run_notebook.py hanoi-book.ipynb hanoi-book.ipynb
3. The extension is not signed by DuckDB, so the notebooks open DuckDB with
   `allow_unsigned_extensions` (in the DuckDB shell, start it with `duckdb -unsigned`).
4. The notebooks install the spatial extension the DuckDB repository distributes
   (`INSTALL spatial`). For DuckDB v1.5.6 its optimizer rewrites the `&&` operator as a spatial
   join only when its operands are geometries, so queries such as the join of trips and time
   bins of the Hanoi notebook keep MobilityDuck's operator.

### Reproducing the values, timings and figures of the chapter

Every value the chapter quotes, every timing ratio and every plan figure comes from a script of
this directory. The scripts read their inputs from environment variables, so that nothing is
tied to one machine:

| Variable | Meaning |
|---|---|
| `AIS_DIR` | Directory of `aisdk-2026-01-20.csv`: `ais/fetch_data.sh day` of this repository downloads its archive into `data/ais/`, and `unzip` extracts it |
| `PG_AIS` | Connection string of the PostgreSQL database of the AIS data, built by `ais/build.sh` (for example `dbname=ais`) |
| `PG_HANOI` | Connection string of the PostgreSQL database of the Hanoi data (for example `dbname=hanoi`) |
| `HANOI_DIR` | Directory of the CSV files of `hanoi_sf0.01.zip` (its `data0.01`), for `load/hanoi_duckdb_csv.sql` |
| `CH7_DB_DIR` | Directory of the DuckDB databases `ais.duckdb`, `ships.duckdb` and `hanoi.duckdb` |
| `MOBILITYDUCK_EXTENSION` | Path of `mobilityduck.duckdb_extension`, obtained as the previous section says |
| `CH7_PLAN_DIR` | Output directory of the plan figures |
| `DUCKDB` | The DuckDB v1.5.6 shell (default: `duckdb` on the `PATH`) |

`run_duckdb.sh <database> <script.sql>` runs a script of this directory in the DuckDB shell,
replacing these variables, and only these, by their values with `envsubst` (on macOS, of the
Homebrew package `gettext`). The Python scripts need the
packages `duckdb==1.5.6`, `psycopg` and `matplotlib`. The timestamps printed by the AIS listings
are those of a session in Central European Time, as the chapter prints them.

#### Loading the data

1. The AIS data: `ais/fetch_data.sh day` and `ais/build.sh` of this repository build the
   PostgreSQL database `PG_AIS`, and `psql "$PG_AIS" -f load/aisinput_pg.sql` adds to its table
   `AISInput` the point geometry that the PostGIS queries of Sect. "Querying DuckDB" read. Then
   `./run_duckdb.sh "$CH7_DB_DIR/ais.duckdb" values/section_duckdb.sql` runs the listings of
   Sect. "DuckDB" in their order: it creates the table `AISInput` of `ais.duckdb` from the CSV
   file, prints the result of each listing, and writes `$AIS_DIR/ais.parquet`.
2. The table `Ships` of MobilityDuck:
   `./run_duckdb.sh "$CH7_DB_DIR/ships.duckdb" load/ships_duckdb.sql` reads it from `PG_AIS`
   with `postgres_scan`, as the listing "Table Creation, Population, and Indexing" does.
3. The Hanoi data are `hanoi_sf0.01.zip` of
   [MobilityDB-BerlinMOD-Hanoi](https://github.com/MobilityDB/MobilityDB-BerlinMOD-Hanoi),
   downloaded from the link of its README. `psql "$PG_HANOI" -v dir=<directory of its CSV files>
   -f load/hanoi_pg.sql` loads them into PostgreSQL, and
   `./run_duckdb.sh "$CH7_DB_DIR/hanoi.duckdb" load/hanoi_duckdb.sql` copies the tables into
   DuckDB. `COPY` reads the CSV files on the database server: with PostgreSQL in a container,
   copy them into it (`docker cp data0.01 <container>:/tmp/hanoi`) and give `dir` their path
   there (`-v dir=/tmp/hanoi`). Without PostgreSQL,
   `./run_duckdb.sh "$CH7_DB_DIR/hanoi.duckdb" load/hanoi_duckdb_csv.sql` builds the same tables
   in DuckDB from the CSV files in `HANOI_DIR`. The loaded data hold 2,903 trips of 12,744,742
   instants, from 2020-06-01 08:00:15.533 to 2020-06-06 04:51:35.92983 UTC, a trip keeping the
   instants that are not exactly redundant, as the MEOS of MobilityDB master and of MobilityDuck
   decides them. `load/hanoi_fingerprint.sql`, run by `psql "$PG_HANOI" -At -f` or by the DuckDB
   shell after loading spatial and MobilityDuck, prints

       trips|2903|12744742|1ff016214762591b2d99b2d3e3525365
       municipalities|30|2bbda5a88b1b4557dc3741dc1f79d4e6
       socson|526|9871.984

#### Values

| Script | What it prints |
|---|---|
| `values/section_duckdb.sql` | The results of the listings of Sect. "DuckDB" |
| `values/ais_duckdb_details.sql` (over `ais.duckdb`) | The numbers of Queries 8 to 10 of Sect. "Querying DuckDB" |
| `values/ais_mduck_values.sql` (over `ships.duckdb`) | The results of the MobilityDuck AIS queries, with the names of the vessels |
| `python values/hanoi_details.py timing/specs/hanoi_mduck.json` | The Hanoi values: row counts, the trips named in the text, totals |
| `psql "$PG_HANOI" -f values/hanoi_numbers_pg.sql` | The same Hanoi numbers recomputed in MobilityDB |

#### Timings

The chapter reports each timing as the ratio of the PostgreSQL time to the DuckDB time, as the
range over three rounds that alternate the engines, each keeping the second of two runs. The
specs of `timing/specs/` hold the queries as the chapter prints them, with the MobilityDB form
where MobilityDB requires another one. Run from `timing/`:

| Command | Timings |
|---|---|
| `python bench.py specs/ais_duckdb.json <out.json>` | Queries 1 to 10 of Sect. "Querying DuckDB" |
| `python bench.py specs/ais_mduck.json <out.json>` | The MobilityDuck AIS queries |
| `python bench.py specs/hanoi_mduck.json <out.json>`, `specs/hanoi_permuni.json`, `specs/hanoi_q28.json` | The Hanoi queries |
| `python bench_sample.py specs/ais_sample.json <out.json>` | The two queries over sampled ships, for 300 and 600 ships |
| `python bench_close_forms.py specs/ais_sample.json <out.json>` | The three forms of the condition of Query `que:close300` |
| `python bench_parquet.py` | The query over the Parquet file against the same query over the CSV file |

#### Plan figures

`figures/make_plans.sh` prints the plans with EXPLAIN ANALYZE into `CH7_PLAN_DIR` and draws the
parts that the figures show (`queryduckdbproc_a`, `queryduckdbproc_b`, `queryprocplan8`,
`mduckq14plan`, `index_plan`, `mobduckq24plan`) with `figures/renderplan.py`.

#### Map figures

The maps of the chapter are drawn with Folium, over the OpenMapTiles
vector tiles of OpenFreeMap drawn by Leaflet.VectorGrid (`figures/vtiles.py`, styles in
`figures/omtstyle.py`), printed to vector PDF by headless Chromium (`figures/vgprint.py`;
`figures/vghybrid.py` embeds a dense marker or trip layer as one lossless image of the pixels of
the map as the book prints it at 300 dpi, so that no viewer resamples it; `figures/pdf_simplify.py`
simplifies the paths of a map below half a pixel of the printed page). A map PDF carries no
text: its labels and legends are TikZ overlays (`<figure>_overlay.tex`) set in the font of the
captions.

1. Install, with Python 3.11 or newer, the Python packages (the figures of the book are drawn
   with these versions) and the Chromium of Playwright, and, for the hybrid maps, `pdftocairo`
   of Poppler:
   `pip install folium==0.20.0 branca==0.8.2 pandas==2.3.3 shapely==2.2.0 matplotlib==3.11.2 pillow==12.3.0 pikepdf==10.16.0 playwright==1.63.0`
   and `playwright install chromium`. Set `CHROME` to use another Chromium executable.
2. In `figures/`, create `data/ais`, `data/hanoi` and `out`, and write the data of the maps,
   which the scripts read and write relative to that folder:
   - `md_figdata.sql` and `duck_figdata.sql` in `ais_ch7.duckdb`, the DuckDB database that
     `mobilityDuckAIS.ipynb` builds with the tables `AISInput` and `ships`;
   - `hanoi_figdata.sql` in `$CH7_DB_DIR/hanoi.duckdb`, or `hanoi_figdata_pg.sql` with `psql`
     in `PG_HANOI`.
3. Draw the maps into `out`: `python3 fig_md.py`, `python3 fig_duck.py` and
   `python3 fig_hanoi.py`; each takes the names of the figures to draw, by default all of them.

#### Flock

The five Flock pipelines run on DuckDB v1.5.6 with Flock from the community repository and two
models served by Ollama 0.24.0: `llama3` (Llama 3 8B) and `gpt-oss:20b`, here on an NVIDIA
GeForce RTX 3060 Laptop GPU. A later Ollama refuses the `llama3` embeddings of pipeline 5, and
the Ollama registry refuses `gpt-oss:20b` to a 0.24.0 client, so a newer client downloads that
model once and 0.24.0 serves it (`flock/results/run.log`). From `flock/`,
`../run_duckdb.sh "$CH7_DB_DIR/hanoi.duckdb" export_tables.sql` writes the three tables they
read as Parquet files, and `duckdb flock.duckdb -c ".read flock_pipelines.sql"` runs them. The answers of a language model
vary from one run to the next, so `flock/results/` holds the results that the tables of the
chapter print, with `run.log`, the log of the run that produced them.

### Exercises

Exercise 7.4 is worked by hand on the table `TestGeo` of the chapter;
`exercises_by_hand.py` computes every number of its answers, with Python alone:

    python3 exercises_by_hand.py

Exercise 7.5 queries the CSV file and the Parquet file of Sect. "Analyzing Non-Persistent Data"
without loading them; `values/section_duckdb.sql` writes the Parquet file first (step 1 above):

    ./run_duckdb.sh :memory: exercises_files.sql

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

