## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 2: Programmatic Mobility Data Science

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The figures of Section 2.2 on MEOS (the types, their memory layout, normalization,
modification and the skip list of the temporal aggregates) are drawn in
[figures/meos.vsdx](figures/meos.vsdx), a Microsoft Visio file. The page `Siplist` holds the
skip list (top), the skip list after a deletion (middle) and after an insertion (bottom), the
figures `skiplist`, `skiplist_delete` and `skiplist_insert` of the book; the page `NewStruct`
holds the memory layout of the temporal types (top) and of the sets and spans (bottom), the
figures `temp_struct` and `setspan_struct`; and the page `Classesss` holds the class diagrams of
the sets and spans (top) and of the temporal types (bottom), the figures `setspan_types` and
`temporal_types`. Each figure is the page exported to PDF and cropped to its drawing.

### Figures

The folder `figures` draws the figures of the chapter drawn from data and recomputes the outputs
that the chapter prints. The maps are drawn with the `explore()` code of the chapter over the
OpenMapTiles vector tiles of OpenFreeMap drawn by Leaflet.VectorGrid (`vtiles.py`, styles in
`omtstyle.py`), printed to vector PDF by headless Chromium (`vgprint.py`); these three helpers are
those of chapter 7. `pdf_simplify.py` of `chapter7/figures` simplifies the paths of the four
smoothing maps below half a pixel of the page as the book prints it; it needs `pikepdf` and
`shapely`, in the Python of the scripts or in the Python named by `PIKEPDF_PY`. A map PDF carries
no text: its labels and legends are TikZ overlays (`<figure>_overlay.tex`) set in the font of the
captions. The scripts write into `figures/out`.

The figures drawn with matplotlib have the size at which the book prints them, so that their text
reads as the captions do: `print_panels.py` lays each panel of the listings of the PyMEOS section
out again at that size, with its text in Latin Modern at 8 points through the PGF backend
(`pdflatex` and the `lmodern` package), as `fig_charts_print.py` does for the MovingPandas section;
a map keeps its frame and loses its coordinates. `fig_bmod_outputs.py` sets the printed outputs in
DejaVu Sans at 6.67 points, the size whose x-height is that of the captions.

1. Install the Python packages (the figures of the book are drawn with these versions) and the
   Chromium of Playwright:
   `pip install movingpandas==0.23.0 pymeos==1.2.1 pymeos_cffi==1.2.0 geopandas==1.2.0 pandas==2.3.3 shapely==2.2.0 matplotlib==3.11.2 folium==0.20.0 branca==0.8.2 mapclassify==2.11.0 stonesoup==1.9.1 scikit-learn==1.9.1 distinctipy==1.3.4 pyarrow==26.0.0 psycopg==3.3.6 pillow==12.3.0 playwright==1.63.0`
   and `playwright install chromium`. Set `CHROME` to use another Chromium executable.
   `fig_charts_print.py` sets its text with `pdflatex` and the `lmodern` package.
2. Put the input data in `figures/data`, or in the folder given by the variable `CH2_DATA`:
   - `aisclean-2026-01-20.csv`, the reports of the table `AISClean` of the AIS database of the
     book (directory `ais` of this repository), written by `figures/export_aisclean.sh` with the
     columns, names and timestamp format of the files of the
     [Danish Maritime Authority](http://aisdata.ais.dk/);
   - `trips.csv`, the first 700 trips of the BerlinMOD-Brussels database of scale factor 0.01
     ([MobilityDB-BerlinMOD](https://github.com/MobilityDB/MobilityDB-BerlinMOD)), written by
     the `COPY ... TO STDOUT` statement of the section Advanced PyMEOS Functionality, saved by
     the client (`psql -d <database> -f trips.sql > trips.csv`);
   - `brussels_communes.csv` and `brussels_region.csv`, from `TheBook/src/main/resources` of
     `project-jmeos.zip`.
3. MovingPandas, on `../2021-01-30_all.csv`: `delhi_check.py` prints every output of
   the section, `mp_toy_check.py` the toy trajectories; `fig_delhi.py` draws the maps
   `mpandas2-*` (it takes the names of the figures to draw, by default all of them), and
   `fig_charts_print.py` the plots `mpandas2-delhisplits` and `mpandas2-generalization_*` at the
   width they are printed at. `delhi_common.py` holds the statements they share.
4. PyMEOS on AIS data, run with `TZ=UTC` (the timestamps of the reports are in UTC):
   `ais_load.py` reads `aisclean-2026-01-20.csv` as the complete example of the chapter and
   writes `ais_filtered.parquet`; `ais_make_input.py` writes `aisinput.csv`, the records of the
   five vessels of the chapter. `pymeos_ais1.py` runs the MovingPandas/PyMEOS example on
   `aisinput.csv` and writes the simplified trajectories that `fig_pymeosais1.py` draws
   (`pymeosais1_a/b`). `pymeos_ais2.py` runs the complete example into the table `pymeos.Ships`
   of the AIS database of the book (variables `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` and
   `PGDATABASE`, by default those of the chapter and `ais`), and
   `PSYCOPG_IMPL=python python3 pymeos_ais2_plot.py` reads one ship back and draws
   `pymeosais2_a/b`.
5. Advanced PyMEOS functionality, on BerlinMOD: `bmod_listings.py` runs the listings of the section on
   `trips.csv`, prints the values the chapter shows and draws the plots `pymeosbmod*` and
   `pymeossimplifications*`; then `fig_bmod_outputs.py` renders the printed outputs
   `pymeosbmod10` and `pymeosbmod12_a/b`, `fig_pymeosbmod2_b.py` draws the map `pymeosbmod2_b`,
   and `fig_pymeosbmod6.py` draws the maps `pymeosbmod6_a/b`.

### Exercises

The folder `exercises` holds the programs of the answers to the MovingPandas and PyMEOS
exercises of the chapter. Run them in that folder with `aisinput.csv` (step 4 above) copied into
it: `mp_a.py`, `mp_b.py` and `mp_c.py` answer the MovingPandas exercise, and `pm_a.py`, `pm_b.py`
and `pm_c.py` the PyMEOS one (`pm_b.py` and `pm_c.py` run the loading part of `pm_a.py`).

### JMEOS Programs

`DOCKER.md` states how to build the Docker image of the JMEOS examples (`Dockerfile`) and run them
in it. The folder `jmeos/src` holds the JMEOS programs of the advanced section and of the JMEOS exercise
in the layout of `TheBook/src` of `project-jmeos.zip`; copied over it, its files take the place of
those of the archive. The programs use the JMEOS of
[MobilityDB/JMEOS](https://github.com/MobilityDB/JMEOS) `main`, generated from the MEOS of
MobilityDB `master`: `jmeos/pom.xml` and `jmeos/tools/refresh.conf` build them as a consumer of
`tools/refresh-binding.sh` of [MEOS-API](https://github.com/MobilityDB/MEOS-API), which builds
libmeos and the JMEOS jar and then the examples, without warnings:
`<MEOS-API>/tools/refresh-binding.sh --binding <the examples>` over the files of `TheBook` with
those of `jmeos` copied over them. `JMEOS03` reads `/data/aisclean-2026-01-20.csv` (or the path
given as argument) with the day/month/year date style of the DMA files and writes the table
`jmeos.Ships` of the AIS database of the book; `PGDBStore` connects with the variables `PGHOST`,
`PGPORT`, `PGUSER` and `PGPASSWORD`, by default those of the chapter. `JMEOS07Extent` prints the instants and the extent of the first two trips
and the extent of all of them, `JMEOS08` computes the speed-time tiles and `JMEOS09` the spatial
tiles (classes `TripsInSpeedTimeTile` and `TripsInTile`); each takes the path of
`berlinmod_trips.csv` as argument. `JMEOS08a`, `JMEOS08b` and `JMEOS10` answer the three items
of the JMEOS exercise with `SpeedTimeTiling`, and read `/data/berlinmod_trips.csv` unless a path
is given. `SizeOfBox` compiles a small C program with `gcc` against `meos.h` to obtain the size
of a MEOS box.
