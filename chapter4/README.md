## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 4: Temporal Poses and Temporal Rigid Geometries

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter uses two datasets. The maritime one is the AIS feed already used in
the previous volume, and is planar: a vessel's orientation is a single angle.
The driving one is nuScenes, and is three-dimensional: orientation needs a
quaternion, interpolation needs the spherical rule, and the sensors form a frame
tree. Between them they exercise the whole of the chapter.

All scripts were last run against **PostgreSQL 18.1, PostGIS 3.6.1 and
MobilityDB 1.4**. `yaw(trgeometry)` requires a MobilityDB built after the
`rotation` -> `yaw` rename; before it, the function is `rotation(trgeometry)`.

### Worked Examples of the Types

pose_examples.sql: every example of the sections introducing `pose`, `tpose` and
`trgeometry`, in the order the chapter gives them. It needs no dataset, so it is
the quickest way to check that an installation has the pose family compiled in.
The comment under each statement is the answer it produced. The examples of the
restriction and spatial functions follow the vessel of the chapter that sails
and then turns in place; the position of its bow halfway through the turn is
linearly interpolated only in a MobilityDB built after `bodyPointTrajectory`
and `centroid` kept the interpolation of the rigid geometry, and a build before
it answers the position at the start of the turn.

geopose.sql: the OGC GeoPose 1.0 examples, including the frame registry and the
encoders for the Basic, Advanced, Chain and Series targets.
geopose_examples.json: the four GeoPose documents shown in the chapter, as
files, so they can be fed to `poseFromGeoPose` directly.

### Maritime Movement

The scripts run in the AIS database of the book, built by `ais/build.sh` of this
repository for January 20, 2026, from its table `AISClean`:

    psql -d ais -f load_turbines.sql
    psql -d ais -f ais_poses.sql
    psql -d ais -f text_numbers.sql

load_turbines.sql: the 111 turbines of the Anholt offshore wind farm, from
OpenStreetMap, into the table `Turbines`.

ais_poses.sql: the listings of the AIS use case of the chapter, as the chapter
prints them and in its order. They keep the reports of `AISClean` that carry a
heading and constant hull dimensions (`AISCleanPoly`, 7,548,980 reports), draw
the hull of each vessel as a polygon in its own frame from the four `SizeA` to
`SizeD` offsets (`ShipShape`), and build one `trgeometry` per vessel
(`ShipsRigid`, 1,949 vessels); then they run the analytical queries of the
chapter: swept area, time inside a zone, path of the bow, rate of turn,
distance of a hull to a point and to a polygon, heading against course,
hull-to-hull distances, the load of an alert belt and the closest point of
approach. The two listings that display every vessel for the MOVE plugin of
QGIS send their rows to no file.

Two details of the conversion are worth knowing before adapting the script. AIS
reports a compass heading, clockwise from North, while a `pose` stores an angle
counter-clockwise from East, so the conversion is `pi()/2 - radians(Heading)`;
and because a `pose` requires its angle in `]-pi, pi]`, every heading of 270
degrees or more -- a quarter of the compass, not an edge case -- needs a full
turn added, or the constructor refuses the value. The times of the AIS data are
in UTC, and so are the instants of the queries.

text_numbers.sql: the numbers the text quotes and no listing prints, on the
tables of ais_poses.sql and load_turbines.sql.

### Autonomous Driving

The nuScenes dataset is distributed by Motional under CC BY-NC-SA 4.0 and must
be obtained from https://www.nuscenes.org/nuscenes after accepting its terms, so
it is not redistributed here. The scripts use the **v1.0-mini** release, which
is a 4 GB download of which only the 32 MB of JSON metadata is needed:

  tar -xzf v1.0-mini.tgz --wildcards "*/*.json"

To run the scripts, with the directory holding the JSON files:

psql -d nuscenes -v dir=/path/to/v1.0-mini -f load_nuscenes.sql

\i nuscenes_queries.sql

load_nuscenes.sql: reads the JSON tables with PostgreSQL's own JSON facilities
-- `pg_read_file` and `jsonb_array_elements`, no external tool -- and builds the
temporal poses and temporal rigid geometries. On v1.0-mini it loads 10 scenes,
404 samples, 31206 ego poses and 18538 annotations, and produces 10 temporal
poses, 881 temporal rigid geometries and 120 sensor mountings. It ends with
three checks; the comments there explain what a surprising answer would mean.

nuscenes_queries.sql: the queries of the driving section -- platform attitude,
body-to-body clearance, swept area, the sensor rig as a pose chain, and the
comparison of orientation against course that shows this dataset carries a
genuine pose.

Two traps in this dataset are worth knowing before writing your own queries.
The `size` field is `[width, length, height]`, **not** length first, so
unpacking it in field order rotates every object by a right angle while leaving
the boxes plausible. And `yaw` is measured counter-clockwise from the x axis
while `azimuth` is measured clockwise from north, so the course in the
convention of the yaw is `90 - azimuth`; comparing the two raw reports a
disagreement almost everywhere for no reason but the convention.

### Exercises

Exercises 4.3 and 4.4 are worked by hand from the distance algorithm and
the nuScenes conventions of the chapter; `exercises_by_hand.py` computes every
number of their answers, with Python alone:

    python3 exercises_by_hand.py

### Figures

`figures/make_figures.sh` draws the figures of the chapter drawn from data into
`$OUT`: `export_ais.py` and `export_nuscenes.py` run the MobilityDB queries of
each figure and write its layers as GeoJSON, together with a spec of the map
figures (the layers, their styles, the extent, and the size), and `render.sh`
draws each spec as vector PDFs in the Python of QGIS, over the OpenStreetMap
Shortbread vector tiles, with `spec_jobs.py`, which writes a job per figure,
and the renderer of the maps of vessels of chapter 3
(`chapter3/figures/storms_qgis_map.py`). The figures that are not maps are drawn by
`export_nuscenes.py` with matplotlib. The databases are named by the PostgreSQL
environment variables, and by `AIS_DB` and `NUSCENES_DB` (default: `ais` and
`nuscenes`). `QGIS_PY` names the Python of QGIS, for instance `python3` on a
Linux installation of QGIS; by default it is the QGIS 3.40 installation of
Windows called from WSL, which needs `$OUT` on a Windows drive.

The wind farm figure also reads the table `Turbines`, which
`load_turbines.sql` loads into the AIS database from `data/anholt_turbines.csv`:
the positions of the 111 turbines of the Anholt offshore wind farm as mapped in
OpenStreetMap, © OpenStreetMap contributors, available under the Open Database
License (https://www.openstreetmap.org/copyright).

| Figure | Script, output |
|---|---|
| The vessels as temporal points and as temporal rigid geometries, in the port of Frederikshavn | `export_ais.py`, `ais_layer_points.pdf`, `ais_layer_hulls.pdf` |
| A ferry turning in the port of Gedser | `export_ais.py`, `ais_turn_swept.pdf`, `ais_turn_paths.pdf` |
| A vessel entering its berth backwards, in the port of Aarhus | `export_ais.py`, `ais_dock.pdf` |
| Closest approach of vessels to the breakwater of the port of Helsingborg | `export_ais.py`, `helsingborg_1.pdf`, `helsingborg_2.pdf` |
| Heading flip of a double-ended ferry | `export_ais.py`, `ais_flip.pdf` |
| Two ferries crossing the Øresund | `export_ais.py`, `ais_encounter_context.pdf`, `ais_encounter_zoom.pdf` |
| Heading and course of a trawler | `export_ais.py`, `ais_crab.pdf` |
| The Anholt offshore wind farm: its turbines, their centroid, and their convex and concave hulls | `export_ais.py`, `ais_windfarm.pdf` |
| A nuScenes scene at one instant | `export_nuscenes.py`, `nus_scene.pdf` |
| Ground swept in a nuScenes scene | `export_nuscenes.py`, `nus_swept.pdf` |
| The sensor rig of the nuScenes vehicle | `export_nuscenes.py`, `nus_rig.pdf` |
| Pitch of the recording vehicle | `export_nuscenes.py`, `nus_pitch.pdf` |
| Objects in the frame of the front camera | `export_nuscenes.py`, `nus_camera.pdf` |

`figures/planar_graph.py` draws the three panels of the figure of the planar
graph of the traversed area (Sect. 4.5.5) and needs no database, only
`shapely`. It builds the 18 segments of the L-shaped body that translates from
placement A to placement B, splits them at their 6 crossings into a planar graph
of 18 nodes and 30 edges, and walks its outer boundary through 9 nodes, with
exact fractions; it checks the area of the walk, 10.625, against the union of
the placements and of the parallelograms swept by the edges, and prints the
counts on the standard error. The panels are TikZ pictures, which the chapter
inputs as its three subfloats:

    OUT=out python3 figures/planar_graph.py

| Figure | Script, output |
|---|---|
| The segments, the planar graph, and the walk along the outer boundary of the area an L-shaped body traverses | `planar_graph.py`, `planar_graph_segments.tex`, `planar_graph_graph.tex`, `planar_graph_walk.tex` |

`figures/traversed_area_figures.py` draws the figures of the traversed areas of
two moving regions and of the three types of holes in a traversed area, and
`figures/distance_figures.py` the outer Voronoi diagram of a convex polygon and
the decompositions of a cross into convex parts. They need only `shapely`. The
first computes each traversed area in the three steps of Sect. 4.5.5: the
movement is sampled at poses at most 0.05 radians apart, every edge sweeps the
convex hull of its placements at two consecutive poses, and the pieces and the
placements are merged; it prints the area and the number of holes of each
traversed area on the standard error. The second checks that the parts of each
decomposition of the cross are convex and that their union is the cross, the
three parts of the first one disjoint and the two of the second overlapping. Both write TikZ pictures,
which the chapter inputs:

    OUT=out python3 figures/traversed_area_figures.py
    OUT=out python3 figures/distance_figures.py

| Figure | Script, output |
|---|---|
| Traversed area of two moving regions | `traversed_area_figures.py`, `traversed_area_example.tex` |
| Three types of holes in the traversed area of a moving region | `traversed_area_figures.py`, `hole_1.tex`, `hole_2.tex`, `hole_3.tex` |
| Outer Voronoi diagram of a convex polygon | `distance_figures.py`, `outer_voronoi_diagram_polygon.tex` |
| A non-convex object, its decomposition into three disjoint convex parts, and into two overlapping convex parts | `distance_figures.py`, `convex_object.tex`, `convex_decomposition_1.tex`, `convex_decomposition_2.tex` |

### Checking the Text

`text_numbers.sql` computes the numbers the text of the AIS use case quotes and
no listing prints: the close encounters, the pairs of vessels within 100 m of
each other, read as hulls and as antennas, and the approach of the vessels to
the Anholt wind farm (its centroid and its convex and concave hulls). It reads
the tables of `ais_poses.sql` and `load_turbines.sql`, so it runs after them:

    psql -d ais -f text_numbers.sql

The two scripts of `check/` run the listings of the chapter against a database
and need the LaTeX source of the chapter, `chapter4.tex`:

- `check/book_listings.py` reads the listings of the type sections, runs them
  through `psql` and compares each answer with the result the book prints under
  it; its `compare` step writes `pose_examples.sql`, the statements in the order
  of the chapter with their answers:

      python3 check/book_listings.py extract chapter4.tex listings.sql
      psql -X -d <database> -f listings.sql > listings.out 2>&1
      python3 check/book_listings.py compare chapter4.tex listings.out pose_examples.sql

- `check/ais_poses_from_book.py` writes `ais_poses.sql` from the AIS listings of the chapter,
  in its order, so that the script runs the listings as the book prints them:

      python3 check/ais_poses_from_book.py chapter4.tex ais_poses.sql

