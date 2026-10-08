## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 3: Temporal Geometries and Temporal Circular Buffers 

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The case study of the chapter models the underwater noise of vessels as
temporal circular buffers, on one day of AIS data of the Danish Maritime
Authority. The scripts run against **PostgreSQL 18, PostGIS 3.6 and
MobilityDB 1.4**.

### Datasets

- **AIS**: the day 2025-01-01, http://aisdata.ais.dk/2025/aisdk-2025-01-01.zip,
  unzipped as `aisdk-2025-01-01.csv`.
- **Ports, sea cells and protected areas**: the files `port.csv`,
  `sea_cells.csv.gz` and `natural_areas.csv.gz` read by the loader.

All the files are placed in one directory on the database server, which holds
no other file with the extension `.csv` sorting before the AIS file.

### Loading

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

### Queries

tcbuffer_case_study.sql: the queries of the case study, in the order of the
chapter, with the answer of each one as a comment: the area affected by the
noise of a fishing vessel, the relationships between its moving region and a
protected area, and the temporal distance between the moving regions of the
fishing vessel and of a passenger vessel, the exposure of the marine and
coastal protected areas to the noise of the whole day (the table `Exposure`),
and the acoustic encounters, the pairs of vessels whose noise regions overlap
while their trajectories stay apart (the tables `Encounter` and
`SeaEncounter`).

### Figures

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
