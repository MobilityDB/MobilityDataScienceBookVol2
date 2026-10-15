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

### Figures

The folder `figures` draws the maps and plan figures of the chapter with the Folium code of the
notebooks, over the OpenMapTiles vector tiles of OpenFreeMap drawn by Leaflet.VectorGrid
(`vtiles.py`, styles in `omtstyle.py`), printed to vector PDF by headless Chromium (`vgprint.py`;
`vghybrid.py` embeds a dense marker layer as one lossless image). A map PDF carries no text: its
labels and legends are TikZ overlays (`<figure>_overlay.tex`) set in the font of the captions.

1. Install the Python packages (the figures of the book are drawn with these versions) and the
   Chromium of Playwright, and, for the hybrid maps, `pdftocairo` of Poppler:
   `pip install folium==0.20.0 branca==0.8.2 pandas==2.3.3 shapely==2.2.0 matplotlib==3.11.2 pillow==12.3.0 pikepdf==10.16.0 playwright==1.63.0`
   and `playwright install chromium`. Set `CHROME` to use another Chromium executable.
2. In the folder `figures`, create `data/ais`, `data/hanoi` and `out`, and write the data of
   the maps, which the scripts read and write relative to that folder:
   - `md_figdata.sql` and `duck_figdata.sql` in the DuckDB database of `mobilityDuckAIS.ipynb`;
   - `hanoi_figdata.sql` in the DuckDB database of `hanoi-book.ipynb`, or
     `hanoi_figdata_pg.sql` with `psql` in the MobilityDB database of the BerlinMOD-Hanoi
     generator below.
3. Draw the maps into `out`: `python3 fig_md.py`, `python3 fig_duck.py` and
   `python3 fig_hanoi.py`; each takes the names of the figures to draw, by default all of them.
4. `plan_pdf.py` and `plan_png.py` draw a block of the text of a DuckDB `EXPLAIN ANALYZE` as a
   vector PDF or a PNG; their docstrings give the arguments.

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

