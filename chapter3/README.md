## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 3: Temporal Geometries and Temporal Circular Buffers 

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter has two use cases: the wind fields of the Atlantic storms of 2024
as temporal geometries, on the best tracks of the National Hurricane Center of
NOAA, and the underwater noise of vessels as temporal circular buffers, on one
day of AIS data of the Danish Maritime Authority. The scripts run against
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

- **AIS**: the day 2025-01-01, http://aisdata.ais.dk/2025/aisdk-2025-01-01.zip,
  unzipped as `aisdk-2025-01-01.csv`.
- **Ports, sea cells and protected areas**: the files `port.csv`,
  `sea_cells.csv.gz` and `natural_areas.csv.gz` read by the loader.

All the files are placed in one directory on the database server, which holds
no other file with the extension `.csv` sorting before the AIS file.

#### Loading

tcbuffer_load.sql defines the loading functions. Loading one day builds the
table `VesselTrip`, with the trajectory of each trip (`Trip`), the source level
of its noise (`SL`), the radius of the area affected by the noise (`Radius`),
the resulting temporal circular buffer (`Noise`), and its traversed area, and
the table `NaturalAreas`:

    \i tcbuffer_load.sql
    SET tcbuffer.datadir = '/absolute/path/to/data/';
    SELECT tcbuffer_load(1);

The source level follows the reference spectrum model of MacGillivray and de
Jong for the one-third octave band of 63 Hz, and the radius assumes spherical
spreading down to the ambient noise level of the sea cell, capped at 10 km.

#### Queries

tcbuffer_case_study.sql: the queries of the case study, in the order of the
chapter, with the answer of each one as a comment: the area affected by the
noise of a fishing vessel, the relationships between its moving region and a
protected area, and the temporal distance between the moving regions of the
fishing vessel and of a passenger vessel, the exposure of the marine and
coastal protected areas to the noise of the whole day (the table `Exposure`),
and the acoustic encounters, the pairs of vessels whose noise regions overlap
while their trajectories stay apart (the tables `Encounter` and
`SeaEncounter`).

text_numbers.sql: the numbers the text of the case study quotes and no listing
prints, on the tables tcbuffer_case_study.sql builds, so it runs after it: how
many trips the noise of reaches how many protected areas their trajectories do
not enter (the table `ExposureAll`), how long the most exposed areas stay quiet
during the day, and the number, the median length and the greatest separation
of the encounters at sea.

#### Figures

The directory figures/ holds export_uwn.sh, which writes the layers of the two
figures of the case study from the database as GeoPackage files, and the job
files that the renderer of chapter 5 (`chapter5/figures/render_map.py`) draws
with QGIS. The job files state the output and layer paths of a Windows machine
and are edited to the directory where export_uwn.sh writes.

`figures/make_figures.sh` draws the other figures of the chapter drawn from data
into `$OUT`, with the pipeline of chapter 4 (`chapter4/figures/figlib.py` and
`render.sh`): `export_figures.py` writes the layers and the spec of four maps, the
noise region of the fishing vessel leaving Østerby, the hull of a ro-ro vessel
turning in Göteborg (from the AIS database of chapter 4), the protected area W
in the Øresund at the instant the noise of 85 vessels reaches it, and an
acoustic encounter at sea, and `fig_dist_tcbuffer_point.py` draws the turning
point of the temporal distance between a temporal circular buffer and a point,
at the circle MobilityDB answers. The databases are named by the PostgreSQL
environment variables, and by `NOISE_DB` and `AIS_DB` (default: `noise` and
`ais`).
