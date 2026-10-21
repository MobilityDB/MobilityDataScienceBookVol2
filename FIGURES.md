## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### The figures of the book and the scripts that draw them

Each figure of the book that is drawn from data is drawn by the scripts of this repository named
below, relative to its root; the README of each chapter states how to run them and the data and
databases they need. The files are those of the directory `figs/` of the book. A figure whose
producer is a drawing or a TikZ source of the book is a diagram, which carries no data; the
figures that are TikZ pictures written inside the text of a chapter are not listed.

### Chapter 2

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 2.1 | Four bus trajectories in Delhi | `mpandas2-delhitrips.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.2 | Speeds of the four trajectories of Fig. 2.1 | `mpandas2-delhispeeds.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.3 | First trajectory of Fig. 2.1, the second of the collection tc, colored by its speed, with the bounding box of each of its four parts | `mpandas2-delhitraj.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.4 | The four parts of the trajectory in Fig. 2.3, each in the color of its bounding box in Fig. 2.3, each map fitted to its part | `mpandas2-splits_a.pdf`, `mpandas2-splits_b.pdf`, `mpandas2-splits_c.pdf`, `mpandas2-splits_d.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.5 | (a) Original trajectory, the second part of the trajectory in Fig. 2.4; (b) DP generalization; (c) Top-Down Time Ratio generalization | `mpandas2-generalization_a.pdf`, `mpandas2-generalization_b.pdf`, `mpandas2-generalization_c.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.6 | (a) Stops computed for the third leg of the split trajectory (part 3 in Fig. 2.4); (b) Segments corresponding to those stops | `mpandas2-stops.pdf`, `mpandas2-segments.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.7 | Stops of a collection of four trajectories | `mpandas2-stops-collect.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.8 | Trajectory aggregation | `mpandas2-stops-agg.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.9 | (a) Original trajectories; (b) Smoothed trajectories | `mpandas2-smooth_a.pdf`, `mpandas2-smooth_b.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.10 | Smoothing of the speed of an individual trajectory: (a) original trajectory; (b) smoothed trajectory | `mpandas2-smooth-speed_a.pdf`, `mpandas2-smooth-speed_b.pdf` | `chapter2/figures/fig_delhi.py` |
| 2.11 | Alternative models for storing time-varying information: tuple versus attribute timestamping | `tuple_attribute.pdf` | Drawing of the book |
| 2.12 | A temporal sequence with (a) discrete, (b) linear, and (c) step interpolation | `tsequence_disc`, `tsequence_linear`, `tsequence_step` | Drawing of the book |
| 2.13 | A temporal sequence set with (a) linear and (b) step interpolation | `tsequenceset_linear`, `tsequenceset_step` | Drawing of the book |
| 2.14 | Set and span types | `setspan_types` | Visio source `chapter2/figures/meos.vsdx` |
| 2.15 | Set and span data structures | `setspan_struct` | Visio source `chapter2/figures/meos.vsdx` |
| 2.16 | Bounding box types | `boxes` | Drawing of the book |
| 2.17 | Temporal type hierarchy | `temporal_types` | Visio source `chapter2/figures/meos.vsdx` |
| 2.18 | Temporal data structures | `temp_struct` | Visio source `chapter2/figures/meos.vsdx` |
| 2.19 | Normalizing a temporal sequence with (a) linear and (b) step interpolation | `norm_seq_linear`, `norm_seq_step` | Drawing of the book |
| 2.20 | Normalizing a temporal sequence set with (a) linear and (b) step interpolation | `norm_seqset_linear`, `norm_seqset_step` | Drawing of the book |
| 2.21 | Skip list data structure | `skiplist` | Visio source `chapter2/figures/meos.vsdx` |
| 2.22 | Modifying a skip list: (a) delete and (b) insert | `skiplist_delete`, `skiplist_insert` | Visio source `chapter2/figures/meos.vsdx` |
| 2.23 | Insert operation for temporal values | `temporal_insert` | Drawing of the book |
| 2.24 | Update operation for temporal values | `temporal_update` | Drawing of the book |
| 2.25 | Delete operation for temporal values | `temporal_delete` | Drawing of the book |
| 2.26 | Modification operations for temporal tables in SQL | `modif_sql` | Drawing of the book |
| 2.27 | (a) A simplified trajectory using PyMEOS; (b) Same trajectory after exporting it to MovingPandas | `pymeosais1_a.pdf`, `pymeosais1_b.pdf` | `chapter2/figures/pymeos_ais1.py`, `chapter2/figures/fig_pymeosais1.py` |
| 2.28 | (a) A MobilityDB trajectory obtained after loading from PyMEOS; (b) The SOG values | `pymeosais2_a.pdf`, `pymeosais2_b.pdf` | `chapter2/figures/pymeos_ais2.py`, `chapter2/figures/pymeos_ais2_plot.py` |
| 2.29 | Trajectories overlaid with Brussels' municipalities | `pymeosbmod2_a.pdf`, `pymeosbmod2_b.pdf` | `chapter2/figures/bmod_listings.py` (a), `chapter2/figures/fig_pymeosbmod2_b.py` (b) |
| 2.30 | Trajectories (a) inside and (b) outside Brussels | `pymeosbmod3_a.pdf`, `pymeosbmod3_b.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.31 | Trajectories clipped to each municipality in Brussels | `pymeosbmod4.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.32 | The third trip of vehicle 34 on June 4, 2020: (a) the trip, in green; (b) its DP simplification, in red; (c) its SED simplification, in blue | `pymeossimplifications-trip_a.pdf`, `pymeossimplifications-trip_b.pdf`, `pymeossimplifications-trip_c.pdf` | `chapter2/figures/fig_pymeossimplifications_trip.py` |
| 2.33 | (a) Original trajectories; (b) Trajectories simplified with DP; (c) Trajectories simplified with SED | `pymeossimplifications_a.pdf`, `pymeossimplifications_b.pdf`, `pymeossimplifications_c.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.34 | Bulk aggregation: (a) the spatial extent of the trips, the blue rectangle; (b) the number of trips under way at each instant, with the temporal extent between the two red lines | `pymeosbmod9_a.pdf`, `pymeosbmod9_b.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.35 | Bulk aggregation as in Fig. 2.34, considering four hours of trajectories: (a) the spatial extent, the blue rectangle; (b) the number of trips under way, with the temporal extent between the two red lines | `pymeosbmod5_a.pdf`, `pymeosbmod5_b.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.36 | Streaming aggregation of the spatial extent, within the extent of all the trips, in red: (a) the extent of the first 40 trips, in blue; (b) the extent of the first 80 trips, in green | `pymeosbmod6_a.pdf`, `pymeosbmod6_b.pdf` | `chapter2/figures/fig_pymeosbmod6.py` |
| 2.37 | Portion of the result of the space and speed tiling | `pymeosbmod10.pdf` | `chapter2/figures/fig_bmod_outputs.py` |
| 2.38 | (a) Trajectory tilings; (b) Speed tilings | `pymeosbmod11_a.pdf`, `pymeosbmod11_b.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.39 | (a) Coloring of trajectories within a tile, one color per tile; (b) Coloring of speeds within a tile | `pymeosbmod7_a.pdf`, `pymeosbmod7_b.pdf` | `chapter2/figures/bmod_listings.py` |
| 2.40 | (a) Aggregation of trajectories per tile; (b) Aggregation of speed per tile | `pymeosbmod12_a.pdf`, `pymeosbmod12_b.pdf` | `chapter2/figures/fig_bmod_outputs.py` |

### Chapter 3

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 3.1 | The hierarchy of spatiotemporal types in MEOS | `tspatialfull` | Drawing of the book |
| 3.2 | A deformable moving region: the area reached by the underwater noise of a fishing vessel leaving the harbor of Østerby on January 20, 2026, between 4:30 and 5:30, as a temporal circular buffer (shaded, with a continuous outline), its circular buffers at the instants 4:30, 4:45, 5:00, 5:15, and 5:30 (dashed outlines), each with its center and its time, and its trajectory in blue | `ais_noise_region.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/noise_region_job.py` |
| 3.3 | Three representations of the Atlantic tropical storms of 2024 | `storms_tpoint`, `storms_tgeo`, `storms_tcbuffer` | `chapter3/figures/make_figures.sh`, `chapter3/figures/storms_jobs.py`, `chapter7/figures/pdf_simplify.py` |
| 3.4 | A fixed-shape moving region: the hull of a vessel turning in the harbor of Göteborg on January 20, 2026, between 18:39 and 18:45, from light to dark orange, and the trajectory of its GPS antenna in blue | `ais_hull_turn.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/hull.sql` |
| 3.5 | The wind fields of 50 and 64 knots of Hurricane Milton at 2:30 on October 10, 2024 (observed at 0:00), the field of 64 knots observed at 6:00 (dotted outline), and the track of Milton with its observations, in the UTM zone 17N | `storms_tampa` | `chapter3/figures/make_figures.sh`, `chapter3/figures/storms_jobs.py` |
| 3.11 | Trajectory of a fishing vessel (in blue) and the area affected by its underwater noise (in blue) on January 20, 2026 | `traversed_area_uwn.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/uwn_noise.sql`, `chapter3/figures/uwn_layers.sql` |
| 3.12 | The marine strategy area W in the Øresund (shaded in green) and the noise regions of the 27 vessels heard in it at 17:45 on January 20, 2026, the noise of 16 of which reaches 10 kilometers | `ais_exposure_w.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/exposure_w.sql` |
| 3.13 | The trips of a fishing vessel and a passenger vessel and the areas affected by their noise, in red and blue, respectively | `shortest_line_uwn.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/uwn_noise.sql`, `chapter3/figures/uwn_layers.sql` |
| 3.14 | Two vessels sailing from the Great Belt around Skagen into the Skagerrak on January 20, 2026, the tanker TRIUMF in red and the cargo vessel PUMA in blue | `ais_encounter_sea_a.pdf`, `ais_encounter_sea_b.pdf` | `chapter3/figures/make_figures.sh`, `chapter3/figures/encounter_sea_job.py` |

### Chapter 4

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 4.12 | Overview of the OGC GeoPose standard | `GeoPose.png` | Drawing of the book |
| 4.22 | Bounding box (in red) of an arrow-shaped polygon rotating by π about its center while translating to the right | `bbox_example.pdf` | Drawing of the book |
| 4.23 | Traversed area of two moving regions | `traversed_area_example.tex` | `chapter4/figures/traversed_area_figures.py` |
| 4.24 | Computing the area traversed between two poses | `planar_graph_segments.tex`, `planar_graph_graph.tex`, `planar_graph_walk.tex` | `chapter4/figures/planar_graph.py` (writes the TikZ panels) |
| 4.25 | Holes in the traversed area | `hole_1.tex`, `hole_2.tex`, `hole_3.tex` | `chapter4/figures/traversed_area_figures.py` |
| 4.28 | Outer Voronoi diagram of a convex polygon | `outer_voronoi_diagram_polygon.tex` | `chapter4/figures/distance_figures.py` |
| 4.29 | Non-convex object with an optimal convex decomposition | `convex_object.tex`, `convex_decomposition_1.tex` | `chapter4/figures/distance_figures.py` |
| 4.31 | Heading flip of a double-ended ferry | `ais_flip.pdf` | `chapter4/figures/export_ais.py` |
| 4.33 | The vessels in the port of Frederikshavn at 10:00 on January 20, 2026, displayed as temporal points (a) and as temporal rigid geometries (b) | `ais_layer_points.pdf`, `ais_layer_hulls.pdf` | `chapter4/figures/export_ais.py` |
| 4.34 | A ferry turning in the port of Gedser | `ais_turn_swept.pdf`, `ais_turn_paths.pdf` | `chapter4/figures/export_ais.py` |
| 4.35 | A vessel entering its berth backwards | `ais_dock.pdf` | `chapter4/figures/export_ais.py` |
| 4.36 | Closest approach of vessels to the port of Helsingborg | `helsingborg_1.pdf`, `helsingborg_2.pdf` | `chapter4/figures/export_ais.py` |
| 4.37 | Reference geometries of a wind farm | `ais_windfarm.pdf` | `chapter4/figures/export_ais.py` |
| 4.39 | Heading and course of a turning vessel | `ais_crab.pdf` | `chapter4/figures/export_ais.py` |
| 4.40 | Two ferries crossing the Øresund | `ais_encounter_context.pdf`, `ais_encounter_zoom.pdf` | `chapter4/figures/export_ais.py` |
| 4.41 | Pitch of the recording vehicle | `nus_pitch.pdf` | `chapter4/figures/export_nuscenes.py` |
| 4.42 | A nuScenes scene at one instant | `nus_scene.pdf` | `chapter4/figures/export_nuscenes.py` |
| 4.43 | Ground swept in a nuScenes scene | `nus_swept.pdf` | `chapter4/figures/export_nuscenes.py` |
| 4.44 | The sensor rig of the nuScenes vehicle | `nus_rig.pdf` | `chapter4/figures/export_nuscenes.py` |
| 4.45 | Objects in the frame of the front camera | `nus_camera.pdf` | `chapter4/figures/export_nuscenes.py` |

### Chapter 5

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 5.2 | Bathymetry around the island of Læsø | `bathymetry_laeso` | `chapter5/figures/make_figures.sh` (job_bathymetry_laeso.json) |
| 5.3 | The seabed of a reef area north-east of Læsø | `seabed_slope`, `seabed_tpi` | `chapter5/figures/make_figures.sh`, `chapter5/figures/export_seabed.sh` |
| 5.4 | The depth under a vessel between two reports | `depth_under_vessel` | `chapter5/figures/make_figures.sh`, `chapter5/figures/overlay_depth_under_vessel.py` |
| 5.9 | An AIS track on the H3, QUADBIN, and S2 grids | `cellgrids` | `chapter5/figures/make_figures.sh`, `chapter5/figures/export_cellgrids.sql`, `chapter5/figures/cellgrids_panels.py`, `chapter5/figures/cellgrids_compose.tex` |
| 5.10 | Vessel-hours per H3 cell | `traffic_h3` | `chapter5/figures/make_figures.sh` (job_traffic_h3.json), `chapter10/figures/extract_base.py` |

### Chapter 6

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 6.1 | A tourist application in Paris | `s-m-itinerary.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/add_arrondissements.py`, `chapter6/figures/render_spec.py` (s-m-itinerary.json), `chapter6/figures/overlay_labels.py` |
| 6.2 | A spatiotemporal trajectory of a vehicle in Paris (at the bottom) with three semantic trajectories specifying the speed (in black, in km/h), the temperature (in violet, in C), and the road type (in red), and several semantic trajectories derived from them | `patterns` | `chapter6/figures/render_spec.py` (patterns_map.json), `chapter6/figures/patterns_vector.py`, over the diagram drawn in Visio (figs/chap6/patterns.vsdx of the book) |
| 6.3 | Trip #6 that crosses cells 56 and 57 | `trip6linevspoint.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (trip6linevspoint.json), `chapter6/figures/overlay_labels.py` |
| 6.4 | Trip #275 (blue line) that crosses cells 54, 64, 63, 73, 72, 82, and 83 | `tiledpoint.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (tiledpoint.json), `chapter6/figures/overlay_labels.py` |
| 6.5 | Two tessellations for spatially segmenting the trips: a regular grid and the districts in Delhi | `griddistricts.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (griddistricts.json), `chapter6/figures/overlay_labels.py` |
| 6.6 | Result of Query 6.8 for TripId = 12 | `grid-allincrease.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (grid-allincrease.json), `chapter6/figures/overlay_labels.py` |
| 6.7 | Pattern 87, 86, 87 for Trip #2684 in the continuous representation (blue line) | `missingpattern.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (missingpattern.json), `chapter6/figures/overlay_labels.py` |
| 6.8 | (a) Result of Query 6.14: Trip #3324 passes through New Delhi from and to South East Delhi | `alternate.pdf`, `development.pdf` | `chapter6/figures/export.sql`, `chapter6/figures/render_spec.py` (alternate.json and development.json), `chapter6/figures/overlay_labels.py` |

### Chapter 7

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 7.1 | Architecture of a current in-memory database system | `imdbsarch` | TikZ source of the book (figs/chap7/imdbsarch.tex) |
| 7.2 | (a): Projection and grouping in the query plan for Query 7.2; (b): Same operations, for Query 7.3 Observe the duplicate projection of T here | `queryduckdbproc_a.pdf`, `queryduckdbproc_b.pdf` | `chapter7/figures/make_plans.sh`, `chapter7/figures/plans_ais.sql` |
| 7.3 | Hourly centroids of the ships' positions | `duckdbcentroid.pdf` | `chapter7/figures/duck_figdata.sql`, `chapter7/figures/fig_duck.py` |
| 7.4 | Execution plan for Query 7.8 | `queryprocplan8.pdf` | `chapter7/figures/make_plans.sh`, `chapter7/figures/plans_ais.sql` |
| 7.5 | For the ship in red, the ships in green are at a distance of less than 1,000 meters at a given time | `ships1000m.pdf` | `chapter7/figures/duck_figdata.sql`, `chapter7/figures/fig_duck.py` |
| 7.6 | Number of neighbors that are within 1,000 m of each ship's latest position | `countships1000m.pdf` | `chapter7/figures/duck_figdata.sql`, `chapter7/figures/fig_duck.py` |
| 7.7 | Five nearest neighbours (circles) of the reference ship (red square) at its latest position | `k-5-NN.pdf` | `chapter7/figures/duck_figdata.sql`, `chapter7/figures/fig_duck.py` |
| 7.8 | Execution plan of a query using an R-tree index | `index_plan.pdf` | `chapter7/figures/make_plans.sh`, `chapter7/figures/plan_index.sql` |
| 7.9 | Trajectories between the ports of Rødby and Puttgarden | `rodbyputt.pdf` | `chapter7/figures/fig_md.py`, `chapter7/figures/md_figdata.sql` |
| 7.10 | Vessel activity between the ports of Rødby and Puttgarden, within an alert belt | `belt.pdf` | `chapter7/figures/fig_md.py`, `chapter7/figures/md_figdata.sql` |
| 7.11 | Portion of the query plan for Query 7.20 | `mduckq14plan.pdf` | `chapter7/figures/make_plans.sh`, `chapter7/figures/plan_close300.sql` |
| 7.12 | (a): General view of closest ships; (b): Detailed view of closest ships, in the harbour of Esbjerg | `pointsclose300_a.pdf`, `pointsclose300_b.pdf` | `chapter7/figures/md_figdata.sql`, `chapter7/figures/fig_md.py` |
| 7.13 | (a): General view of closest trajectories near Esbjerg; (b): Detailed view of closest trajectories within the harbour of Esbjerg | `close300_a.pdf`, `close300_b.pdf` | `chapter7/figures/md_figdata.sql`, `chapter7/figures/fig_md.py` |
| 7.14 | (a): Trajectories passing through a buffer with a radius of 500m around the port of Copenhagen; (b): Trajectories within a radius of 1000m of the port of Copenhagen, for at least 20 minutes | `copenh.pdf`, `copenhstop.pdf` | `chapter7/figures/md_figdata.sql`, `chapter7/figures/fig_md.py` |
| 7.15 | (a): Trips in Hanoi; (b): Municipalities in Hanoi | `tripsHanoi.pdf`, `municipalitiesHanoi.pdf` | `chapter7/figures/fig_hanoi.py` |
| 7.16 | Trip that crosses the largest number of municipalities in Hanoi | `maxtripmuni.pdf` | `chapter7/figures/hanoi_figdata.sql`, `chapter7/figures/fig_hanoi.py` |
| 7.17 | Trips that cross municipalities in Hanoi (the six municipalities crossed by the largest number of trips) | `tripdistricts.pdf` | `chapter7/figures/hanoi_figdata.sql`, `chapter7/figures/fig_hanoi.py` |
| 7.18 | Total distances traveled per municipality | `totaldistpermuni.pdf` | `chapter7/figures/fig_hanoi.py` |
| 7.19 | Portion of the execution plan for Query 7.29 | `mobduckq24plan.pdf` | `chapter7/figures/make_plans.sh` |
| 7.20 | Two trips at less than ten meters from each other | `closetrips.pdf` | `chapter7/figures/fig_hanoi.py` |
| 7.21 | (a): General view of meeting trips; (b) Detailed view along a street | `closetraj_a.pdf`, `closetraj_b.pdf` | `chapter7/figures/fig_hanoi.py` |
| 7.22 | Trips passing at less than ten meters from a point | `tripsinstants.pdf` | `chapter7/figures/hanoi_figdata.sql`, `chapter7/figures/fig_hanoi.py` |

### Chapter 8

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 8.1 | Interactions between a Spark application and the cluster manager | `sparkApplicactions.pdf` | TikZ source of the book (figs/chap8/sparkApplicactions.tex) |
| 8.2 | Spark unified stack | `sparkstack.pdf` | TikZ source of the book (figs/chap8/sparkstack.tex) |
| 8.3 | Spark SQL components | `sparkArq.pdf` | `chapter8/figures/sparkArq.tex` |
| 8.4 | Spark processing scheme | `spark-new.pdf` | TikZ source of the book (figs/chap8/spark-new.tex) |
| 8.5 | RDD lineage DAG generated by the Spark application | `rddapp.pdf` | TikZ source of the book (figs/chap8/rddapp.tex) |
| 8.6 | DAG generated by the Spark application using DataFrames | `dataframerdd.pdf` | TikZ source of the book (figs/chap8/dataframerdd.tex) |
| 8.7 | NYC stations, computed using Spark and Sedona | `nycstations.pdf` | `chapter8/figures/citibike_maps.py` |
| 8.9 | History Server | `incomplete.png` | `chapter8/figures/history_server.py` |
| 8.10 | Incomplete running applications in the History Server | `incomplete2.png` | `chapter8/figures/history_server.py` |
| 8.11 | Spark application completed jobs | `thesparkapp.png` | `chapter8/figures/history_server.py` |
| 8.12 | Completed queries for the application | `completedquery.png` | `chapter8/figures/history_server.py` |
| 8.14 | Plan Visualization: DAG | `plan_snake2.pdf` | Graphviz source of the book (figs/chap8/plan_snake2.dot) |
| 8.15 | (a) Choropleth maps showing the number of trips per starting station; (b) The destination station for afternoon trips starting in Manhattan and ending in another borough | `map1new.pdf`, `map2new.pdf` | `chapter8/figures/citibike_maps.py` |
| 8.16 | Ratio between pick-up and returns in stations located in a radius of 500 m from Columbus circle in Manhattan, between 6 pm and 5 am | `columbus.pdf` | `chapter8/figures/citibike_maps.py`, `chapter8/figures/export_maps.sql` |
| 8.17 | The 5,086 flights over Europe on March 1, 2026, between 8 and 9 o'clock UTC | `flightsQuery1.pdf` | `chapter8/figures/flights_queries_maps.py` |
| 8.18 | The 245 flights leaving Brussels on March 1, 2026: their routes (red) and their destinations (black) | `flightsQuery2.pdf` | `chapter8/figures/flights_queries_maps.py` |
| 8.19 | Distance in kilometers flown over each country by the flights over Europe on March 1, 2026, on a logarithmic scale | `flightsQuery3.pdf`, `flightsQuery3_scale` | `chapter8/figures/flights_queries_maps.py` |
| 8.20 | Number of aircraft in the air over Europe on March 1, 2026, at each instant of the day | `flightsQuery4.pdf` | `chapter8/figures/flights_queries_maps.py` |
| 8.21 | The flights within 15 km of the holding fixes of London Heathrow, between 2,000 and 5,000 meters, on March 1, 2026: Bovingdon (red), Lambourne (blue), Ockham (green), and Biggin Hill (purple) | `flightsQuery5.pdf` | `chapter8/figures/flights_queries_maps.py` |
| 8.22 | Dashboard 1: flights leaving Brussels on March 1, 2026, below 2,000 meters while they climb | `flightsDashboard1_left.pdf`, `flightsDashboard1_right.pdf`, `flightsDashboard1_scale` | `chapter8/figures/flights_maps.py` |
| 8.23 | Dashboard 2: distance in three dimensions between THY325 and BOX571 on March 1, 2026, on a logarithmic scale | `flightsDashboard2_distance.pdf` | `chapter8/figures/flights_dashboard2_maps.py` |
| 8.24 | Dashboard 2: THY325 (red) and BOX571 (blue) on March 1, 2026 | `flightsDashboard2_map.pdf`, `flightsDashboard2_altitude.pdf` | `chapter8/figures/flights_dashboard2_maps.py` |
| 8.25 | Dashboard 3: flights on March 1, 2026 | `flightsDashboard3_left.pdf`, `flightsDashboard3_right.pdf`, `flightsDashboard3_scale` | `chapter8/figures/flights_maps.py` |

### Chapter 9

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 9.1 | Flink architecture | `flinkarch.pdf` | TikZ source of the book (figs/chap9/flinkarch.tex) |
| 9.2 | Flink task execution scheme | `taskexec.pdf` | TikZ source of the book (figs/chap9/taskexec.tex) |
| 9.3 | A dashboard representing the balance between pick-ups and returns, for each station | `slidejoin.pdf` | `chapter9/figures/citibike_dashboards.sh` (example slidejoin) |
| 9.4 | Top 10 stations in real-time | `top10sliding.pdf` | `chapter9/figures/citibike_dashboards.sh` (example top10) |
| 9.5 | Borough occupation in real-time | `boroughoccup.pdf` | `chapter9/figures/citibike_dashboards.sh` (example boro) |
| 9.6 | Manhattan geofencing dashboard | `geofence.pdf` | `chapter9/figures/citibike_dashboards.sh` (example geofence) |
| 9.7 | The trajectories of the 3,046 aircraft over Europe in the window of the stream from 8 to 9 o'clock UTC on March 1, 2026 | `flightsStreamQuery1.pdf` | `chapter8/figures/flights_stream_maps.py` |
| 9.8 | The 190 flights arriving at Brussels on March 1, 2026, as sessions of the stream: their routes (green) and their origins (black) | `flightsStreamQuery2.pdf` | `chapter8/figures/flights_stream_maps.py` |
| 9.9 | The dashboards of the air traffic stream while the day is replayed at 20 times its real speed, with the answers up to noon | `flightsStreamDashboards.pdf` | `chapter9/figures/flights_dashboards.sh` |

### Chapter 10

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 10.1 | Three analytical architectures | `dw_dl_lh` | TikZ source of the book (figs/chap10/dw_dl_lh.tex) |
| 10.2 | Where a table format keeps its metadata: in files next to the data (Iceberg, Delta Lake, Hudi) or in a database (DuckLake) | `table_formats` | TikZ source of the book (figs/chap10/table_formats.tex) |
| 10.3 | From one month of AIS data to the 8 files a query reads | `usefulness_month`, `usefulness_query`, `usefulness_files`, `usefulness_admitted` | `chapter10/figures/render_pdfs.sh`, `chapter10/figures/tracks_image_pdf.py`, `chapter10/figures/extract_base.py`, `chapter7/figures/pdf_simplify.py` |
| 10.4 | Two-level skipping | `data_skipping` | TikZ source of the book (figs/chap10/data_skipping.tex) |
| 10.5 | The metadata-column bridge | `metadata_bridge` | TikZ source of the book (figs/chap10/metadata_bridge.tex) |
| 10.6 | The H3 cell cover of a vessel track, the pilot vessel PILOT II returning west to its berth at Gedser on January 20, 2026, between 22:20 and 22:56, with 180 reported positions (dark dots) over 15.2 km | `h3cover_trip_res8`, `h3cover_trip_res9` | `chapter10/figures/render_pdfs.sh` |
| 10.7 | The H3 cell cover of a protected area: Hesselø and the stone reefs around it (WDPA 555557023), 41.0 km² with the island of Hesselø as a hole, outlined in green | `h3cover_region_res8`, `h3cover_region_res9` | `chapter10/figures/render_pdfs.sh` |
| 10.8 | The architecture of a mobility data lakehouse: four layers from the queries down to the object storage, which holds the three datasets, each derived from the previous one | `architecture` | TikZ source of the book (figs/chap10/architecture.tex) |
| 10.9 | Cleaning and segmentation of the track of vessel 257584000 on January 15, 2026: (a) 40,973 raw observations; (b) 32 segments, 15 moves and 17 stops | `segment_raw`, `clean_segmented` | `chapter10/figures/render_pdfs.sh` |
| 10.10 | In-file orderings on one day of segments | `inorder_L0`, `inorder_L0X`, `inorder_L0Z`, `inorder_L0H` | `chapter10/figures/inorder_figures.py` |
| 10.11 | The four partitioning schemes | `partitionings` | TikZ source of the book (figs/chap10/partitionings.tex) |
| 10.12 | Regular (L2) and adaptive (L3) tiling of the same trip, a cargo vessel crossing the Rødby–Puttgarden strait on 15 January 2026, over the 50 km region cells (dashed) | `tiling_L2_trip`, `tiling_L3_trip` | `chapter10/figures/render_pdfs.sh` |
| 10.13 | One crossing of a ferry from Rødby to Puttgarden on 15 January 2026, as stored in L0 and L3, and what Query 10.1 keeps of it | `q101_rodby`, `q101_puttgarden`, `q101_overview` | `chapter10/figures/render_pdfs.sh` |
| 10.14 | (a) The portion of the bytes of the table that a query reads after pruning, and (b) the speedup over L0, for the layouts of Table 10.4 | `layout_results` | TikZ source of the book (figs/chap10/layout_results.tex), with the values of the evaluation of the MobilityLakehouse benchmark |

### Chapter 11

| Figure | Content | Files | Scripts |
|---|---|---|---|
| 11.1 | Task-specific models and a foundation model | `fm_paradigm` | TikZ source of the book (figs/chap11/fm_paradigm.tex) |
| 11.2 | A pre-normalization Transformer encoder layer | `encoder_layer` | TikZ source of the book (figs/chap11/encoder_layer.tex) |
| 11.3 | Rotary position embedding in one plane of an attention head | `rope` | TikZ source of the book (figs/chap11/rope.tex) |
| 11.4 | Four candidate tokens of the same trajectory | `tokenizations` | TikZ source of the book (figs/chap11/tokenizations.tex) |
| 11.6 | Natural language as a common representation of context | `language_interface` | TikZ source of the book (figs/chap11/language_interface.tex) |
| 11.7 | Construction of the token of a position | `token_embedding` | TikZ source of the book (figs/chap11/token_embedding.tex) |
| 11.8 | The six masking modes applied to the same trajectory | `masking_modes` | TikZ source of the book (figs/chap11/masking_modes.tex) |
| 11.9 | Division of labor in the use case | `usecase_workflow` | TikZ source of the book (figs/chap11/usecase_workflow.tex) |
| 11.10 | The three tasks on the gap 3584 | `gap3584_tasks_a_v2`, `gap3584_tasks_b`, `gap3584_tasks_legend` | `chapter11/figures/export_gap3584.sql`, `chapter11/figures/fig_gap3584.py` |
| 11.11 | Differences of the mean error per window between crossdomain and linear (left) and between crossdomain and coordinates (right), by task and by the mean speed of the vessel in the window | `errors_paired` | `chapter11/figures/export_errors.sql`, `chapter11/figures/fig_errors.py` |
| 11.12 | Median error of the three models for the windows of moving vessels, at 3 knots or more, as a function of the number of minutes to the nearest visible position for recovery, and after the last visible position for prediction | `errors_isolation`, `errors_horizon` | `chapter11/figures/export_errors.sql`, `chapter11/figures/fig_errors.py` |
| 11.13 | Filling a gap from its two bounding reports p_a and p_b: the straight segment of the baseline linear, and the cubic Hermite curve of Query 11.13 | `hermite_gap4907.pdf`, `hermite_gap7902.pdf`, `hermite_turn209276000.pdf`, `hermite_turn210620000.pdf` | `chapter11/figures/make_hermite.sh`, `chapter11/figures/export_hermite.py` |
| 11.14 | A gap between the reports (p_a, t_a) and (p_b, t_b) of a vessel | `gap_bounds` | TikZ source of the book (figs/chap11/gap_bounds.tex) |
| 11.15 | The gap 5452 and the protected areas of Table 11.16 | `errors_q14_gap5452` | `chapter11/figures/export_errors.sql`, `chapter11/figures/fig_errors.py` |
