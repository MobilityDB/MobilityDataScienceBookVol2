## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 3: Temporal Geometries, Circular Buffers, and Point Clouds

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter has three use cases: the wind fields of the Atlantic storms of
2024 as temporal geometries, on the best tracks of the National Hurricane
Center of NOAA, the underwater noise of vessels as temporal circular buffers,
on January 20, 2026, from the AIS database of the book, and two multibeam
surveys of the seabed off Rostock as temporal point clouds. The scripts run
against **PostgreSQL 18, PostGIS 3.6 and MobilityDB 1.4**; the point clouds
also need pgPointCloud and a MobilityDB that includes the pull request
MobilityDB/MobilityDB#3245 (see below).

### The Wind Fields of the Atlantic Storms

The scripts of the directory `storms` build the tables of the use case of the
section "Temporal Geometries and Temporal Geographies" from the data of NOAA,
for any season and basin, so that the same analysis can be repeated on a later
season.

#### Dataset

The GIS archive of the National Hurricane Center,
https://www.nhc.noaa.gov/gis/best_track/, publishes for each tropical cyclone
an archive `<basin><number><year>_best_track.zip`, such as
`al142024_best_track.zip` for Hurricane Milton, holding four shapefiles:

| Shapefile | Content |
|---|---|
| `AL142024_pts` | The observations of the track, every six hours and at landfall: valid time `DTG` (`YYYYMMDDHH`, UTC), position, intensity, pressure, Saffir-Simpson category, type and name |
| `AL142024_lin` | The track as lines between the observations |
| `AL142024_radii` | For each synoptic time and each wind speed of 34, 50 and 64 knots, the radius of each quadrant in nautical miles and the polygon they define |
| `AL142024_windswath` | For each wind speed, the area it reaches over the life of the cyclone |

The coordinates are longitudes and latitudes in degrees, on a sphere of radius
6,371.2 km, loaded in SRID 4326.

#### Pipeline

    ./storms_download.sh 2024                 # al by default, into ./data/al2024
    ./storms_load.sh 2024 storms              # Points2024, Lines2024, Radii2024, Swath2024
    psql -d storms -v year=2024 -f storms.sql
    psql -d storms -f storms_queries.sql

storms_download.sh reads the index of the archive and downloads and unpacks
every best track of the season. storms_load.sh loads the shapefiles of each
kind into one table with `shp2pgsql -s 4326`; the connection parameters other
than the database are read from `PGHOST`, `PGPORT` and `PGUSER`. storms.sql
builds:

| Table | Content |
|---|---|
| `StormPoints` | One row per observation, with the storm identifier, its final name, the timestamp and the position |
| `StormRadii` | One row per wind radii polygon, with its wind speed and timestamp |
| `StormSwath` | One row per wind swath |
| `Storms<year>_tgeo` | The wind field of a storm for a wind speed, as a `tgeography(SequenceSet, Geometry, 4326)` |
| `Storms<year>_tpoint` | The track of a storm, as a `tgeompoint` |
| `Storms<year>_tcbuffer` | The wind field as a `tcbuffer`, the minimum bounding circle of each value, and the area it traverses |

A storm is kept when at least one observation of its track is tropical or
subtropical (types TD, TS, HU, SD and SS). This leaves out the potential
tropical cyclones, systems for which NHC issues advisories although they never
become tropical, such as AL082024 in 2024, and keeps the 18 storms of the book.
A new sequence starts whenever two observations are more than one day apart.

storms_queries.sql holds the queries of the section, with the answer of each
one as a comment, for the season 2024.

### The Underwater Noise of Vessels

#### Datasets

The case study runs in the AIS database of the book, built by `ais/build.sh` of
this repository for January 20, 2026, and reads its tables `Ships`, `AISClean`
and `Vessels`, and two tables of chapter 5: `Port`, the areas of the Danish
ports of GISCO, and `NaturalAreas`, the 283 protected areas of Denmark of the
World Database on Protected Areas (WDPA).

#### Loading

    cd ../chapter5
    bash fetch_data.sh aux               # GISCO ports and the WDPA of Denmark
    bash build_aux_data.sh               # data/port.csv, data/natural_areas.csv.gz
    psql -d ais -f load_aux_tables.sql   # the tables Port and NaturalAreas
    cd ../chapter3
    psql -d ais -f ships_noise.sql

The WDPA may not be redistributed, so `fetch_data.sh` downloads it from Protected
Planet; the README of chapter 5 explains how to select its release.
ships_noise.sql creates the functions `ComputeVc` and `ComputeSL`, the tables
`VesselClass` and `PortAreas`, and adds to `Ships` the column `Noise`, the
temporal circular buffer of the noise of each vessel under way.

The source level follows the reference spectrum model of MacGillivray and de
Jong for the one-third octave band of 63 Hz, from the type and the length of the
vessel in `Vessels` and the speed of each report of `AISClean`. The radius
assumes spherical spreading down to an ambient noise level of 80 dB, capped at
10 km. The model applies to a vessel under way: at the reports whose speed
exceeds 3 knots, and outside the port areas.

#### Queries

tcbuffer_case_study.sql: the queries of the case study, in the order of the
chapter, with the answer of each one as a comment: the area affected by the
noise of a fishing vessel, the relationships between its moving region and a
protected area, the exposure of the marine and coastal protected areas to the
noise of the whole day (the table `Exposure`), the temporal distance between
the moving regions of the fishing vessel and of a passenger vessel, and the
acoustic encounters, the pairs of vessels whose noise regions overlap while
their trajectories stay apart (the table `Encounter`).

text_numbers.sql: the numbers the text of the case study quotes and no listing
prints, on the tables tcbuffer_case_study.sql builds, so it runs after it: the
vessels whose noise is computed and the length and the period under way of the
fishing vessel, the smallest distance between the trajectories of the two
vessels, how many vessels the noise of reaches how many protected areas their
trajectories do not enter (the table
`ExposureAll`), how long the protected areas stay quiet during the day, and the
number and the median length of the encounters at sea.

exercises.sql: the exercises of the chapter on the database of the case study
and on temporal circular buffers of literal values, with the answer of each one
as a comment, run after tcbuffer_case_study.sql.

#### Figures

`figures/make_figures.sh` draws the maps of the chapter into `$OUT` as vector
PDFs over the OpenStreetMap vector tiles:

| Script | Layers | Map |
|---|---|---|
| `noise_region_job.py` | The noise region of the fishing vessel SLESVIG leaving Østerby between 4:30 and 5:30, its circles at 4:30, 4:45, 5:00, 5:15 and 5:30, and its trajectory | `ais_noise_region.pdf` |
| `hull.sql` | Six placements of the hull of the ro-ro vessel FICARIA SEAWAYS turning in Göteborg, from the table `ShipsRigid` of chapter 4, and the trajectory of its GPS antenna | `ais_hull_turn.pdf` |
| `exposure_w.sql` | The protected area W and the noise regions of the vessels heard in it at the instant of the largest number of them | `ais_exposure_w.pdf` |
| `encounter_sea_job.py` | The trajectories of TRIUMF (red) and PUMA (blue) with their positions at 4:00, 12:00 and 20:00, and the traversed areas of their noise with its circles at these instants | `ais_encounter_sea_a.pdf`, `ais_encounter_sea_b.pdf` |
| `uwn_layers.sql`, `uwn_noise.sql` | The trajectories and the traversed areas of the noise of the fishing vessel and of the passenger vessel, the protected areas around Læsø, and the shortest lines between the two noise regions | `traversed_area_uwn.pdf`, `shortest_line_uwn.pdf` |
| `storms_jobs.py` | The tracks of the Atlantic storms of 2024 and their observations, their wind radii polygons of 34, 50 and 64 knots, and the areas that their temporal circular buffers traverse; the wind fields of Milton around Tampa at 2:30 on October 10, the instant of Query 3.1 | `storms_tpoint.pdf`, `storms_tgeo.pdf`, `storms_tcbuffer.pdf`, `storms_tampa.pdf` |

Each SQL script writes GeoJSON layers in longitude and latitude. The job
`job_<map>.json` of each of these maps states its extent, its size, and the style
of each layer, and `hybrid_pdf.py` draws it with QGIS and the renderer of chapter
5 (`chapter5/figures/render_map.py`). `noise_region_job.py` and
`encounter_sea_job.py` write their layers in EPSG:25832 together with their job,
which `storms_qgis_map.py` draws. The maps of vessels follow one color code: one
vessel in blue, two vessels in blue and red, the protected areas in green. `storms_jobs.py` writes the
same job `storms_<map>.json` for each storm map, in longitude and latitude, and
`storms_qgis_map.py` draws it; `pdf_simplify.py` of `chapter7/figures` simplifies the
wind radii of `storms_tgeo.pdf` below half a pixel of the map as the book prints it,
with the Python named by `PIKEPDF_PY` (with `pikepdf` and `shapely`). The script also
draws with `fig_dist_tcbuffer_point.py` the turning point of the temporal
distance between a temporal circular buffer and a point, at the circle
MobilityDB answers. The databases are named by the PostgreSQL environment
variables and by `AIS_DB` and `STORMS_DB` (default: `ais` and `storms`); `QGIS_PY` names the Python of QGIS, which is by default the QGIS
3.40 installation of Windows called from WSL.

### Temporal Point Clouds and the Seabed Surveys

The scripts of the directory `soundings` load the two multibeam survey lines of
the use case "Seabed Surveys" into the AIS database of the book, and run the
listings of the section "Temporal Point Clouds", the queries of the use case,
and Exercise 3.5.

#### Software

Besides PostgreSQL 18 and PostGIS 3.6, the scripts need the extension
`pointcloud` ([pgPointcloud](https://github.com/pgpointcloud/pointcloud) 1.2),
and a MobilityDB built with its point clouds (`-DALL=ON`) from a master branch
that includes the function `swath(tpcpatch)` and the pull request
[MobilityDB/MobilityDB#3245](https://github.com/MobilityDB/MobilityDB/pull/3245),
which writes a schema inserted into the tables `pointcloud_schemas` and
`pointcloud_dimensions` of MobilityDB into the catalog `pointcloud_formats` of
pgPointCloud. `load_soundings.sql` states the schema in the tables of MobilityDB
only, and the function `pcpatch` of pgPointCloud, with which it builds the
patches, reads `pointcloud_formats`: without #3245 it fails with
`no entry in "public.pointcloud_formats" for pcid = 1`. The listings of the raw
files are written by `mblist` and `mbnavlist` of
[MB-System](https://github.com/dwcaress/MB-System) 5.8.2, whose master branch
does not build with GDAL 3.8; `MBSYSTEM` names its installation (default:
`$BOOK_ENV/mbsystem`).

#### Dataset

| Data | Source | Terms |
|---|---|---|
| Two survey lines at 400 kHz, `20190514_124053_kh1905_400khz.s7k` (2.1 GB) and `20191022_085450_kh1910_400khz.s7k` (1.1 GB) | Schulze, I., Feldens, P.: Multibeam echosounder data used for Seasonal Change of Multifrequency Backscatter in three Baltic Sea Habitats, [PANGAEA 945743 and 945782](https://doi.org/10.1594/PANGAEA.946056) | CC-BY-4.0; not suitable for navigation |

#### Pipeline

    cd soundings
    export DATA=$PWD/data PGDATABASE=ais
    bash fetch_soundings.sh          # the two raw files from PANGAEA
    bash prep_soundings.sh           # their listings with MB-System
    psql -f load_soundings.sql       # pcid 1, Pings, Swaths, Tracks
    bash run_all.sh                  # every script, out/ compared with expected/

`prep_soundings.sh` writes, for each line, the CSV file of the soundings that
`mblist` does not flag (the time of the ping, the ping number, the longitude,
the latitude, the topography, the amplitude, and the beam) and the file `.nav`
of the position of the vessel at each ping. `load_soundings.sql`, which takes
about a minute and a half, builds:

| Table | Content |
|---|---|
| `Pings` | One patch of the schema 1 (X, Y, Z, Amplitude, Beam, in EPSG:25832) per ping, with the survey line `Line` and the time `T` of the ping: 4,851 pings and 2,390,742 soundings in May, 3,358 pings and 1,643,152 soundings in October |
| `Swaths` | One temporal patch with discrete interpolation per survey line, whose instants are the pings of the line |
| `Tracks` | The trip of the vessel along each line as a `tgeompoint`, one position per ping, a position repeated by consecutive pings kept once |

The positions are transformed once into EPSG:25832, when the data are loaded.
`fetch_data.sh soundings` and `load_all.sh soundings` of chapter 5 run the same
scripts.

#### Queries

`run_all.sh` runs the scripts below on the database named by the PostgreSQL
environment variables, writes the output of each one to `out/`, and compares it
with `expected/`, the output of the run that gives the answers of the book on
MobilityDB master with #3245. Each script states, before each listing, the
answer the book prints.

| Section of the chapter | Script |
|---|---|
| Temporal Point Clouds: a point and a temporal patch of the schema 1 | `point_clouds.sql` |
| Use Case: Seabed Surveys: the survey lines, the swath against the traversed areas of the vessel over the whole October line and over ten seconds, and the queries on the square of 10 meters where the lines cross, with the numbers the text quotes | `case_soundings.sql` |
| Exercise 3.5 | `exercises.sql` |

#### Figures

`figures/make_figures_soundings.sh`, which `figures/make_figures.sh` runs last,
draws the figures of the point clouds and of the use case into `$OUT` from the
tables of `load_soundings.sql` in `AIS_DB`:

| Script | Layers | Figure |
|---|---|---|
| `export_survey_vessel.sh`, `job_pcl_swath.json`, `job_pcl_line.json` | The pings of the October line, as their footprints and their soundings, and the hull of the vessel at the same instants, every two seconds over the ten seconds from 08:54:50 to 08:55:00 (a) and at seven pings spread over the whole line (b), the trajectory of the antenna, and the swath of the pings, with the frame of (a) in (b) | `pointcloud_swath.pdf`, `pointcloud_line.pdf` |
| `export_survey_vessel.sh`, `job_pcl_compare.json`, `overlay_pcl.py` | The trajectory of the antenna, the traversed areas of the vessel as a temporal circular buffer and as a temporal rigid geometry, and the swath, over the ten seconds, with the legend of the four temporal types | `pointcloud_compare.pdf`, `pointcloud_overlay.tex` |
| `export_survey_vessel.sh`, `job_excerpt_rigid.json`, `job_excerpt_buffer.json`, `overlay_excerpt.py` | The traversed areas of the rigid geometry (a) and of the circular buffer (b) over the ten seconds, with their values every two seconds and the trajectory of the antenna | `excerpt_rigid.png`, `excerpt_buffer.png`, `excerpt_overlay.tex` |
| `export_soundings.sh`, `job_soundings_overview.json`, `job_soundings_closeup.json`, `overlay_soundings.py` | The mean topography of the soundings of the two lines in cells of one meter, the trips of the vessel, and the square where the lines cross (a); the soundings within 1.5 meters of the center of the square (b) | `soundings_overview.png`, `soundings_closeup.png`, `soundings_overlay.tex` |
| `export_soundings.sh`, `soundings_per_ping.tex` | The soundings that each ping put into the square, from the aggregate `tnpoints`, plotted with pgfplots | `soundings_per_ping_20190514.csv`, `soundings_per_ping_20191022.csv` |
| `scalebars.py` | The scale bars of the maps of the moving regions: the noise region, the hull, and the point cloud over ten seconds and over the whole line, and the four temporal types | `ais_noise_region_scaled.tex`, `ais_hull_turn_scaled.tex`, `pointcloud_swath_scaled.tex`, `pointcloud_line_scaled.tex`, `pointcloud_compare_scaled.tex` |

`export_survey_vessel.sh` places the vessel as the queries of
`case_soundings.sql` do, computes the swath with the function `swath` of
MobilityDB, and takes the extent of the frame from `job_pcl_swath.json`.
`hybrid_pdf.py` draws the three jobs `job_pcl_*.json` as vector PDFs, and
`render.sh` of chapter 5 the four other jobs as the images their `output`
names. The overlays write the LaTeX that the book inputs, with the labels, the
legends, and the scale bars in the style of the captions; `overlay_excerpt.py`
reads the areas of its two captions from the database.
