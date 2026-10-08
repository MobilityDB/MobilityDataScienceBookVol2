## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

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

Prerequisite: the AIS input script of the previous volume, which builds the
`AISInputFiltered` table. It is in the volume 1 companion repository, chapter 5,
as `ais_input.sql`. The dataset used is the day 2024-03-01, downloadable from
https://web.ais.dk/aisdata/aisdk-2024-03-01.zip

To run the scripts:

\i ais_poses.sql

\i aisPoseDashboards.sql

ais_poses.sql: filters the records that carry a usable heading and hull
dimensions, draws the hull of each vessel as a polygon in its own frame from the
four `SizeA` to `SizeD` offsets, and builds one `trgeometry` per vessel. On the
day 2024-03-01 the volume 1 script loads 15512927 records and keeps 9637460
after filtering; of those, 7010528 carry both a heading and consistent hull
dimensions, giving 1626 vessels that can be represented as rigid geometries.

Two details of the conversion are worth knowing before adapting the script. AIS
reports a compass heading, clockwise from North, while a `pose` stores an angle
counter-clockwise from East, so the conversion is `pi()/2 - radians(Heading)`;
and because a `pose` requires its angle in `]-pi, pi]`, every heading of 270
degrees or more -- a quarter of the compass, not an edge case -- needs a full
turn added, or the constructor refuses the value. Note
that it replaces the `Ships` table built by the volume 1 script, whose `Trip` is
a `tgeompoint`; chapter 4 needs the rigid-geometry form, so use a dedicated
database if you want both.

aisPoseDashboards.sql: the analytical queries of the chapter, written as a
maritime authority would ask them -- swept area, hull-to-hull clearance, time
inside a zone, rate of turn, and the difference between where a vessel points
and where it goes.

Three queries meet limits of MobilityDB 1.4 on a full day of traffic, and the
scripts mark each one at the point where it bites, with a workaround where one
exists:

- hull-to-hull distance raises `Temporal distance: Cycle detected` for a few
  pairs -- 3 of 118 bounding-box neighbours on 2024-03-01, all involving one
  vessel. The hulls concerned are valid and convex; it is a convergence failure
  in the closest-feature tracking rather than a data problem.
- `atGeometry` on a rigid geometry reports that exact restriction with a
  rotating segment is not implemented. The region a rotating body sweeps has
  curved boundaries, so this one is genuinely unimplemented.
- distance to a `LineString` -- a quay, a fairway centreline -- reports an
  unsupported geometry type, because the sequence path accepts only points and
  polygons. Buffering the line into a thin polygon is the workaround.

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

### Figures

`figures/make_figures.sh` draws the figures of the chapter drawn from data into
`$OUT`: `export_ais.py` and `export_nuscenes.py` run the MobilityDB queries of
each figure and write its layers as GeoJSON, together with a spec of the map
figures (the layers, their styles, the extent, and the size), and `render.sh`
draws each spec with `render_figures.py` in the Python of QGIS, over an
OpenStreetMap basemap. The figures that are not maps are drawn by
`export_nuscenes.py` with matplotlib. The databases are named by the PostgreSQL
environment variables, and by `AIS_DB` and `NUSCENES_DB` (default: `ais` and
`nuscenes`). `QGIS_PY` names the Python of QGIS, for instance `python3` on a
Linux installation of QGIS; by default it is the QGIS 3.40 installation of
Windows called from WSL, which needs `$OUT` on a Windows drive.

The wind farm figure also reads the table `WindTurbine`, which
`load_turbines.sql` loads into the AIS database from `data/anholt_turbines.csv`:
the positions of the 111 turbines of the Anholt offshore wind farm as mapped in
OpenStreetMap, © OpenStreetMap contributors, available under the Open Database
License (https://www.openstreetmap.org/copyright).

| Figure | Script, output |
|---|---|
| The vessels as temporal points and as temporal rigid geometries, in the port of Frederikshavn | `export_ais.py`, `ais_layer_points.png`, `ais_layer_hulls.png` |
| A ferry turning in the port of Gedser | `export_ais.py`, `ais_turn_swept.png`, `ais_turn_paths.png` |
| A vessel entering its berth backwards, in the port of Køge | `export_ais.py`, `ais_dock.png` |
| Heading flip of a double-ended ferry | `export_ais.py`, `ais_flip.png` |
| Two ferries crossing the Øresund | `export_ais.py`, `ais_encounter_context.png`, `ais_encounter_zoom.png` |
| Heading and course of a trawler | `export_ais.py`, `ais_crab.png` |
| The Anholt offshore wind farm: its turbines, their centroid, and their convex and concave hulls | `export_ais.py`, `ais_windfarm.png` |
| A nuScenes scene at one instant | `export_nuscenes.py`, `nus_scene.png` |
| Ground swept in a nuScenes scene | `export_nuscenes.py`, `nus_swept.png` |
| The sensor rig of the nuScenes vehicle | `export_nuscenes.py`, `nus_rig.pdf` |
| Pitch of the recording vehicle | `export_nuscenes.py`, `nus_pitch.pdf` |
| Objects in the frame of the front camera | `export_nuscenes.py`, `nus_camera.pdf` |
