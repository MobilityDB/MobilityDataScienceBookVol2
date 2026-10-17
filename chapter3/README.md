## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 3: Temporal Geometries and Temporal Circular Buffers 

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter has two use cases: the wind fields of the Atlantic storms of 2024
as temporal geometries, on the best tracks of the National Hurricane Center of
NOAA, and the underwater noise of vessels as temporal circular buffers, on
January 20, 2026, from the AIS database of the book. The scripts run against
**PostgreSQL 18, PostGIS 3.6 and MobilityDB 1.4**.

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
`storms_qgis_map.py` draws it. The script also
draws with `fig_dist_tcbuffer_point.py` the turning point of the temporal
distance between a temporal circular buffer and a point, at the circle
MobilityDB answers. The databases are named by the PostgreSQL environment
variables and by `AIS_DB` and `STORMS_DB` (default: `ais` and `storms`); `QGIS_PY` names the Python of QGIS, which is by default the QGIS
3.40 installation of Windows called from WSL.
