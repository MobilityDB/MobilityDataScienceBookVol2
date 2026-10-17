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
| From one month of AIS data to the files a query reads | `tracks_image_pdf.py` draws the two maps with the month of tracks as one lossless image, the month-wide one over a basemap merged into one GeoPackage by `extract_base.py`; `usefulness_grid.py` of MobilityLakehouse draws the two grids of files |
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
