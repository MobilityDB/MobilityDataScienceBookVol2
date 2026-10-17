## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 5: Rasters and Temporal Tessellations

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter reads fields (bathymetry, waves, temperature, salinity, wind) along
the trips of vessels, computes new fields with map algebra, and aggregates the
trips over discrete global grids. The scripts below download every dataset,
load the database, run every query of the chapter in the order of its
sections, compare the results with those printed in the book, and draw every
map figure.

Every geometry and raster is transformed ONCE, when the data are prepared, to
EPSG:25832, or kept in longitude and latitude in the columns whose name ends in
`LonLat`; no query transforms a geometry.

### Software

- PostgreSQL 18 with PostGIS 3.6 (extensions `postgis` and `postgis_raster`),
  and the extensions `h3` ([h3-pg](https://github.com/zachasme/h3-pg)) and
  `pointcloud` ([pgPointcloud](https://github.com/pgpointcloud/pointcloud)),
  which the MobilityDB extension requires.
- MobilityDB 1.4 at commit 4306c5092b of its master branch, built with all its
  families against the H3 library 4:

      git clone https://github.com/MobilityDB/MobilityDB && cd MobilityDB
      git checkout 4306c5092b
      cmake -S . -B build -DALL=ON -DCMAKE_BUILD_TYPE=Release
      cmake --build build && sudo cmake --install build

  `expected/` holds the results of this commit. The temporal cells, the reading
  of rasters and RaQuet tiles, and the moving regions of the noise case study
  depend on the MobilityDB version: another commit may move an instant or a
  count. The noise case study needs, on top of this commit, the normalization
  of the time of a sequence set and the difference of two span sets of the
  master branch:

      git cherry-pick 15e1d2812e f79133c583
- GDAL 3.8 with its Python bindings, and the PostGIS loader `raster2pgsql`.
- Python 3 with the packages `copernicusmarine` 2.4.1, `cdsapi`, `psycopg2`,
  `pyarrow`, `Pillow`, and `raquet-io` 0.9.0.
- QGIS 3.40 for the figures, and the Python package `shapely` for the basemap of
  the traffic map.

The scripts connect to PostgreSQL through the usual environment variables
(`PGDATABASE`, `PGHOST`, `PGPORT`, ...), and read the datasets from the
directory named by the environment variable `DATA`, by default `data/` below
the working directory.

### Datasets

`fetch_data.sh` puts every dataset into `$DATA` without any account. The AIS
day, the depth model, the ports, and the protected areas are downloaded from
their publishers, whose terms do not allow them to be redistributed or which
publish them openly. The subsets of the Copernicus Marine Service and of ERA5
for the day, whose licences allow their redistribution with the attribution
below, are in `datasets/cmems` and `datasets/era5` of this repository, and
`fetch_data.sh` copies them. With `FROM_PUBLISHER=1` it downloads them again
from their publishers, which needs free accounts: the Copernicus Marine Service
(`copernicusmarine login`, whose username is the e-mail of the account) and the
Copernicus Climate Data Store (an API key in `~/.cdsapirc` and the terms of the
ERA5 dataset accepted on its page).

| Data | Source | Terms |
|---|---|---|
| AIS of 2026-01-20 | [Danish Maritime Authority](http://aisdata.ais.dk/) | as stated by the portal |
| Denmark's Depth Model, 50 m, layer `ddm_50m.dybde` | [Danish Geodata Agency](https://eng.gst.dk/danish-hydrographic-office/denmark-depth-model) | "Indeholder data fra Geodatastyrelsen, Danmarks Dybdemodel, 50 m opløsning"; not suitable for navigation |
| Ports | [GISCO ports 2013](https://ec.europa.eu/eurostat/web/gisco/geodata/transport-networks), Eurostat | © European Union, reuse with acknowledgement |
| Protected areas | [World Database on Protected Areas](https://www.protectedplanet.net), Denmark | UNEP-WCMC and IUCN, Protected Planet; no redistribution, no commercial use |
| Waves, temperature, salinity | Copernicus Marine Service, `BALTICSEA_ANALYSISFORECAST_PHY_003_006`, `BALTICSEA_ANALYSISFORECAST_WAV_003_010`, `NWSHELF_ANALYSISFORECAST_PHY_004_013`, `NWSHELF_ANALYSISFORECAST_WAV_004_014` | "Generated using E.U. Copernicus Marine Service Information" |
| Wind | ERA5 hourly data on single levels, 10 m wind, day 2026-01-20 | CC-BY-4.0 |

`build_aux_data.sh` builds `data/port.csv` and `data/natural_areas.csv.gz`,
the files that `load_aux_tables.sql` and the loader of chapter 3 read. The
ports are the 139 Danish ports of GISCO and the four terminals of
`aux/extra_ports.csv`, each as a buffer of 1000 m, with the names and traffic
flags of `aux/gisco_ports_traffic.csv`. The protected areas are the 283 areas of
the WDPA of Denmark listed, with the identifier the book uses, in
`aux/natural_areas_sites.csv`. Protected Planet serves only its current monthly
release, as shapefiles or as a file geodatabase, and gives no access to older
ones. `fetch_data.sh` downloads the current release in the format it is served
in, and `build_aux_data.sh` reads either format (`WDPA_RELEASE` selects another
release in `$DATA/aux`, for instance `Sep2026`). The geometries of the book are
those of the release of September 2026; `aux/natural_areas_geom.csv` holds the
area, the perimeter, and the number of vertices of each of them, and
`build_aux_data.sh` stops if a listed area is absent from the release it reads
and lists every area whose geometry differs from that of the book. The release
of October 2026 gives the geometries of the book within 0.06 mm.

### Reproducing the chapter

The chapter runs on the AIS database of the book, which `../ais/build.sh`
builds for January 20, 2026 (see `../ais/README.md`): the table `AISClean` of
the cleaned reports, with their speed over ground `SOG`, ship type, length,
draught, position `Geom` in EPSG:25832, and the number `Piece` of the piece of
the track they belong to; the table `Vessels` of the static attributes of each
vessel; and the table `Ships` of the 2,701 vessels of the day, with their trip
`Trip`, in longitude and latitude `TripLonLat`, and their reported speed `SOG`,
course `COG`, heading `Heading`, and rate of turn `ROT` as temporal floats, all
split where a vessel is silent for more than 600 s. The chapter adds its tables
to that database:

    bash fetch_data.sh                 # all datasets into $DATA
    export PGDATABASE=ais              # the AIS database of the book
    bash load_all.sh                   # ports and protected areas, bathymetry,
                                       # hourly fields, RaQuet tiles
    bash run_all.sh                    # every script, out/ compared with expected/
    OUT=/mnt/c/Temp/figs bash figures/make_figures.sh    # every map figure

`load_all.sh` runs, in this order: `build_aux_data.sh` and
`load_aux_tables.sql`; the reprojection of
the bathymetry to EPSG:25832 with `gdalwarp` and its loading into the table
`Bathymetry` with `raster2pgsql`; `prep_waves.sh`, `load_waves.sh`,
`prep_fields.sh`, and `load_field.sh`, which merge the Baltic Sea and North West
Shelf products (the Baltic value where the Baltic model has one), reproject
them once to a 1 km grid (5 km for the wind), and load them as tables
`(ValidTime, Rast)` with one row per tile of each hourly step; and the
conversion of the bathymetry to RaQuet tiles with `raquet-io` and their loading
into the table `BathymetryRaquet` with `load_raquet.py`. Each part can be run
alone, for instance `bash load_all.sh fields`.

`run_all.sh` writes the output of each script to `out/` and compares it with
`expected/`, which holds the output that gives the answers of the book. Each
script states, before each listing of the chapter, the answer the book prints.
### Scripts of the sections

| Section of the chapter | Script |
|---|---|
| Raster Data in PostGIS | `raster_tutorial.sql` |
| Map Algebra | `map_algebra.sql` |
| From PostGIS to MobilityDB: the Depth under a Vessel | `depth_under_vessel.sql` |
| Reading Fields along Trajectories | `fields_along_trips.sql` |
| Discrete Global Grid Systems, Temporal Cells | `grids_and_cells.sql` |
| Case Study: Under-Keel Clearance | `case_clearance.sql` |
| Case Study: Sea State | `case_sea_state.sql`, and `check_wave_overlap.sh` for the agreement of the two wave products |
| Case Study: Underwater Noise and the Depth of the Water | `case_noise.sql` |
| Case Study: Traffic over a Global Grid | `case_traffic.sql` |
| Case Study: Fields in Cloud-Native Storage | `case_raquet.sql` |
| Exercises | `exercises.sql` |

The scripts run in this order, since later ones use tables of earlier ones:
`map_algebra.sql` builds the rasters `Seabed`, `SeabedMean`, and
`BathymetryMin100`, and `grids_and_cells.sql` the table `Ships200` of the first
200 vessels of the day. `case_clearance.sql` and `case_noise.sql` read the
noise of chapter 3: `../chapter3/ships_noise.sql` creates the functions
`ComputeVc` and `ComputeSL` of the source level at 63 Hz, the table
`VesselClass` of the class of each vessel from `Vessels`, the table `PortAreas`
of the port areas, and the column `Noise` of `Ships`, the noise of each vessel
under way (reported speed over 3 knots, outside the port areas) under spherical
spreading with an ambient noise of 80 dB. `run_all.sh` runs it first when
`Ships` has no column `Noise`, which takes a few minutes.

`case_noise.sql` builds the table `ShipNoise` of the trip of each vessel over
the periods of its noise and of its source level, and the function
`noiseRadius` of the chapter, which turns the excess level and the depth along
a trip into the radius of its noise. It builds, for each vessel, the moving
regions of its noise under spherical spreading with an ambient noise of 80 dB,
under spreading depending on the depth of the bathymetry, and under spreading
depending on the depth with the ambient noise raised by the wind of ERA5, and
counts the pairs of a vessel and a protected area reached under each model.
Building the three moving regions of every vessel and the pairs takes
15 to 20 minutes.

### Figures

`figures/make_figures.sh` draws the map figures of the chapter into `$OUT` as
the PDF files the book includes: for each figure, `export_<figure>.sh` writes
its layers from the database, and `hybrid_pdf.py` of `chapter3/figures` draws
`job_<figure>.json` (the layers, their styles, the extent, and the size) with
`render_map.py` in the Python of QGIS as a vector PDF, the OpenStreetMap
Shortbread basemap, the cells, the tracks and the outlines as vectors and a
raster data layer as an embedded image. `QGIS_PY` names that Python, for
instance `python3` on a Linux installation of QGIS; by default it is the QGIS
3.40 installation of Windows called from WSL, which needs `$OUT` on a Windows
drive. `render.sh` draws a job as a PNG image instead. The track and the
protected area follow the colours of the ship figures of the book: one vessel
in blue, protected areas in green.

| Figure | Scripts |
|---|---|
| Bathymetry around the island of Læsø | `export_bathymetry_laeso.sh`, `job_bathymetry_laeso.json` |
| The seabed of a reef area north-east of Læsø | `export_seabed.sh`, `job_seabed_slope.json`, `job_seabed_tpi.json` |
| The depth under a vessel between two reports | `export_depth_under_vessel.sh`, `job_depth_under_vessel.json`, and `overlay_depth_under_vessel.py`, which writes `depth_under_vessel_overlay.tex`, the image with its labels and legend in the style of the captions, which the book inputs |
| An AIS track on the H3, QUADBIN, and S2 grids | `export_cellgrids.sql`, which writes the track of the pilot boat 219002732 leaving Frederikshavn from `Ships`, the protected area 17 of `NaturalAreas`, and the cells of the six panels; `cellgrids_panels.py`, which draws each panel; and `cellgrids_compose.tex`, which sets them in `cellgrids.pdf` |
| Vessel-hours per H3 cell | `export_traffic_h3.sh`, `job_traffic_h3.json`, and `extract_base.py` of `chapter10/figures`, which merges the OSM Shortbread tiles of zoom 5 into the basemap `traffic_base.gpkg`, so that the map of Denmark stays near 1 MB and draws in under a second |
