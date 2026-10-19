## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 10: Mobility Data Pipelines

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.


### Data and queries

The lakehouse of the chapter, from the AIS data of January 2026 published by the Danish Maritime
Authority to the twelve physical layouts, the queries, and the tables of their results, is built
by the scripts of the `benchmark/planar/` directory of the
[MobilityLakehouse](https://github.com/MobilityDB/MobilityLakehouse) repository, whose
`benchmark/README.md` states how to download the data and run them. The figures below are drawn from such a run.
The chapter follows MobilityLakehouse at commit `65f99a9fd8bd26ec4933e0fa0293c956cd8ae732`:

    git clone https://github.com/MobilityDB/MobilityLakehouse.git
    git -C MobilityLakehouse checkout 65f99a9fd8bd26ec4933e0fa0293c956cd8ae732
    MobilityLakehouse/benchmark/ingest/fetch_dma.sh 2026-01-01 2026-01-31
    MobilityLakehouse/benchmark/reproduce.sh 2026-01-01 2026-01-31

The run directory it writes, `data/stage/planar/2026-01-01_2026-02-01` of the checkout, holds the
layout `L0` and the daily layouts such as `L3`; the scripts of this directory read it as
`$LAKEHOUSE_RUN`, and the checkout as `$LAKEHOUSE`.

The listings of the chapter run in the DuckDB shell v1.5.5 with the MobilityDuck extension, as in
chapter 7 (`MOBILITYDUCK_EXTENSION` names the extension, `DUCKDB` the shell):

| File | What it reproduces |
|---|---|
| `queries.sql` | The ten queries of Sect. "Querying the Lakehouse" as printed, with the subqueries the chapter elides written out. Before each statement, `-- @region` names the region it runs on and `-- @gate` the distance of the pairwise queries, as `70_queries.py` of MobilityLakehouse sets them |
| `bind.py` | Binds the parameters of `queries.sql` (`:axmin`, `:t0`, `:d0`, ...) to a window of `windows_25832.csv` of MobilityLakehouse (`1h`, `1day`, `1week`, `1month`) and prefixes the view `trips` over a layout. A parameter inside a quoted literal, such as a bound of an `stbox`, takes the text of its value |
| `walkthrough.sql` | Sect. "Running a Query over a Layout": Query 1 over `L3` and `L0` on the window of one day from 08:00 UTC on January 15, 2026, step by step: the files of each layout and those the statistics keep (264 of the 303 files of `L3` on January 15 and 16, two per port), the share of the bytes of the layout they hold, the rows that pass the MBB filter (102 at Rødby, 93 at Puttgarden on `L3`; 178 and 175 of the 24,166 rows of `L0`), those that pass the refinement (102 and 92; 34 and 28), the vessels (9 and 5, one ferry in 28 rows) and the answer, 4 on both layouts |
| `run_duckdb.sh` | Runs a script in the DuckDB shell after replacing `${LAKEHOUSE_RUN}` and `${MOBILITYDUCK_EXTENSION}` |

For instance, the ten queries on the window of one day over `L3`, and the walkthrough:

    LAKEHOUSE=/path/to/MobilityLakehouse python3 bind.py 1day L3 queries.sql > q.sql
    LAKEHOUSE_RUN=$LAKEHOUSE/data/stage/planar/2026-01-01_2026-02-01 ./run_duckdb.sh q.sql
    LAKEHOUSE_RUN=$LAKEHOUSE/data/stage/planar/2026-01-01_2026-02-01 ./run_duckdb.sh walkthrough.sql

The cell filter of the second listing of Query 1 reads a column `cells` of the cell cover of each
segment; the layouts of MobilityLakehouse do not store it, and the cell covers of the chapter are
measured by `benchmark/planar/cellcover/` of MobilityLakehouse instead.

### Figures

`figures/render_pdfs.sh` writes the figures of the chapter as the PDF files the book includes,
into `$OUT` (`figures/figs/` by default). The maps come from the QGIS jobs and GeoPackages that
`79_layout_figures.sh` and `77_cover_figures.sh` of MobilityLakehouse write into their stages,
named by `LAYOUTFIG_STAGE` and `COVERFIG_STAGE`; `LAKEHOUSE` names the MobilityLakehouse checkout,
whose `coverfig/render_map.py` builds the layers of each job. `QGIS_PY` names the Python of QGIS,
for instance `python3` on a Linux installation of QGIS; by default it is the QGIS 3.40 installation
of Windows called from WSL, which needs the stages on a Windows drive. The basemap is fetched from
the OSM Shortbread tile server.

| Figure | Scripts |
|---|---|
| From one month of AIS data to the files a query reads | `tracks_image_pdf.py` draws the two maps with the month of tracks as one lossless image, the month-wide one over a basemap merged into one GeoPackage by `extract_base.py`, and `pdf_simplify.py` of `chapter7/figures` simplifies their paths below half a printed pixel; `usefulness_grid.py` of MobilityLakehouse draws the two grids of files |
| The H3 cell cover of a vessel track and of a protected area | `hybrid_pdf.py` |
| Cleaning and segmentation of the track of a vessel | `hybrid_pdf.py` |
| In-file orderings on one day of segments | `inorder_figures.py`, run with `RUN` naming the run and `EXT=pdf` |
| Regular and adaptive tiling of the same trip | `hybrid_pdf.py` |
| One crossing of a ferry from Rødby to Puttgarden | `hybrid_pdf.py` |

`hybrid_pdf.py` writes a map as a vector PDF: the basemap, the data layers, the colorbar and the
legend are vectors, and only a raster data layer is an embedded image. `tracks_image_pdf.py` writes
the layers whose path contains a given string as one lossless image between the vector layers below
and above them. `inorder_figures.py` reads the Parquet files of one day of the layouts `L0`, `L0X`,
`L0Z`, and `L0H` with DuckDB and draws each row group's segments and bounding box; the four panels
share one pair of axes.
