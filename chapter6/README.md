## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 6: Semantic Trajectories

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter queries semantic trajectories in two concrete models: the discrete
model, which stores one row per observation or per visit of a cell or a
district, and the continuous model, which stores the trips and their
annotations as temporal values. The scripts below download the data, build the
database, and run every query of the chapter in the order of its sections, in
both models.

### Software

- PostgreSQL 18 with PostGIS 3.6 and the extension `hstore`.
- MobilityDB 1.4, which provides the type `tjsonb` used by the chapter.
- `osm2pgsql` 1.11 or later, which imports the OpenStreetMap data.

The scripts connect to PostgreSQL through the usual environment variables
(`PGDATABASE`, by default `semantic`, `PGHOST`, `PGPORT`, ...), and read the
datasets from the directory named by the environment variable `DATA`, by
default `data/` below the working directory. The server reads the files of the
Delhi observations itself, so it must run on the same machine as the scripts,
and the user must be a superuser or a member of the role
`pg_read_server_files`.

### Datasets

| Data | Source | Terms |
|---|---|---|
| Air-quality observations of buses in Delhi, November and December 2020 | [MobilityDB](https://docs.mobilitydb.com/pub/Delhi_Pollution_2020-Nov-Dec.zip) | as stated by the publisher |
| OpenStreetMap extract of India of January 1, 2021 | [Geofabrik](https://download.geofabrik.de/asia/india-210101.osm.pbf) | [ODbL](https://www.openstreetmap.org/copyright) |
| Hourly weather in Delhi, November and December 2020 (`delhi_weather.csv`) | [Open-Meteo](https://open-meteo.com/en/docs/historical-weather-api) | [CC BY 4.0](https://open-meteo.com/en/license) |

The districts are those of the OpenStreetMap extract of January 1, 2021, the
end of the observation period: the eleven districts of Delhi used in the
chapter. Delhi has since been divided into thirteen districts, so a current
extract gives other districts and other answers to the district queries.

### Scripts

| Script | Content |
|---|---|
| `fetch_data.sh` | Downloads the observations and the OpenStreetMap extract into `$DATA` |
| `build.sh` | Imports the OpenStreetMap data restricted to the bounding box of Delhi, and runs `delhi_load.sql` and `paris_tours.sql` |
| `delhi_load.sql` | Function `delhi_load()`, which builds the tables of the Delhi use case: `DelhiInput`, `WeatherInput`, `WeatherHourly`, `TripPoints`, `Trips`, `Grid`, `TripCells`, `TripVisits`, `TripTiles`, `TripCellsSeq`, `TripTilesSeq`, `Districts`, `PointDistricts`, `PointDistrictSeq`, `TripDistricts`, and `TripDistrictsSeq` |
| `paris_tours.sql` | The tables of the Paris tours: `PoI`, `Tour`, the view `TourPoI`, and `TempTour` |
| `paris_queries.sql` | The queries over the Paris tours, each preceded by its pattern |
| `delhi_queries.sql` | The queries over the Delhi trips, each preceded by its statement and its pattern |
| `delhi_districts.sql` | The pattern of Query `que:point-district` over the districts, in its overlapping, disjoint, and any-length versions |
| `delhi_model_comparison.sql` | The per-cell averages stored in `TripCells` against those computed at query time from `TripTiles` |
| `run_all.sh` | Runs the four query scripts and compares the number of rows of every answer with `expected/` |

### Running

    bash fetch_data.sh
    bash build.sh
    bash run_all.sh

`build.sh` takes about 45 minutes, most of it spent reading the OpenStreetMap
extract of India. `run_all.sh` writes the output of each script to
`out/<script>.out`, and the number of rows of each answer to
`out/<script>.rows`, which it compares with `expected/<script>.rows`.

### Figures

The scripts of `figures/` draw the map figures of the chapter from the database
built by `build.sh`. `export.sql` writes the layers of each figure as GeoJSON in
EPSG:4326, each feature carrying the name of its layer in the property `layer`;
`add_arrondissements.py` adds to the points of interest and itineraries of Paris
the arrondissements of the dataset
[arrondissements](https://opendata.paris.fr/explore/dataset/arrondissements/) of
Paris Data (ODbL), downloaded as GeoJSON. Each figure has a spec (`<figure>.json`:
its GeoJSON, its output, its size, its extent in the map CRS, and its layers from
top to bottom with their QML styles), which `render_spec.py` draws in the Python
of QGIS over the OpenStreetMap Shortbread vector tiles as a vector PDF, without
the labels, which it writes to `<figure>_labels.json`. `overlay_labels.py` then
writes the LaTeX overlay of the figure, a TikZ picture setting the labels over
the PDF in the font of the captions.

The styles of `qml/` are those of the layers of the QGIS projects of the figures,
extracted by `extract_qml.py`; `make_qml.py` derives from them the styles of the
districts of Delhi, of the labeled trips, and of the points of interest of Paris.
The labels are placed in Latin Modern Roman 9, the face of the captions, which
`render_spec.py` reads from `fonts/lmroman9-regular.otf`. The map of the diagram
of the patterns is drawn from `patterns_map.json` and placed in the diagram by
`patterns_vector.py`, which needs `pikepdf`; its input is the diagram as exported from
its Visio source, whose map is the image `/Image12`.

    cd figures
    psql -At -v dir=. -f export.sql
    python3 add_arrondissements.py arrondissements.geojson paris_poi.geojson smi.geojson
    python3 make_qml.py
    mkdir -p fonts && cp "$(kpsewhich lmroman9-regular.otf)" fonts/
    python3 render_spec.py tiledpoint.json      # in the Python of QGIS
    python3 overlay_labels.py tiledpoint.json 0.35 tiledpoint_overlay.tex

| Figure | Spec, GeoJSON | Scale of the overlay |
|---|---|---|
| A tourist application in Paris | `s-m-itinerary.json`, `smi.geojson` | 0.4 |
| The spatiotemporal and semantic trajectories of a vehicle in Paris (map of the diagram) | `patterns_map.json`, none | |
| Trip 6 crossing cells 56 and 57 | `trip6linevspoint.json`, `trip6.geojson` | 0.4 |
| Trip 275 and its cells | `tiledpoint.json`, `trip275.geojson` | 0.35 |
| The grid and the districts of Delhi | `griddistricts.json`, `griddistricts.geojson` | 0.5 |
| Result of Query `que:grid-allincrease` for trip 12 | `grid-allincrease.json`, `trip12.geojson` | 0.35 |
| Pattern {87, 86, 87} of trip 2684 | `missingpattern.json`, `trip2684.geojson` | 0.35 |
| Trips 3324 and 4 over the districts | `alternate.json`, `development.json`, `districts.geojson` | 0.384, 0.4 |

### Answers

The number of answers of the Delhi queries, as given in the chapter.

| Query | Discrete | Continuous |
|---|---|---|
| `que:grid-allincrease` | 1102 | 708 |
| `que:grid-incr-decr` | 348 | 40 |
| `que:grid-span` | 2 | 22 |
| `que:grid-higher` | 4 | 8 |
| `que:grid-raintemphm` | 92 | 71 |
| `que:grid_cell_patt1` (overlapping) | 10478 | 10631 |
| `que:point-district` (overlapping) | 8542 | 8849 |
| `que:point-development` | — | 12792 |
| `que:point-incr` | 708 | 708 |
| `que:point-incr-decr-global` | 38 | 40 |
| `que:point-span` | 94 | 94 |
| `que:point-higher-global` | 8 | 8 |
| `que:point-weather` | 71 | 71 |
