## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### The AIS Database of the Book

Every chapter of the book that uses AIS data reads it from one database, built by the scripts of
this directory and described in the appendix "The AIS Database of the Book". The data are the
position reports that the Danish Maritime Authority publishes at http://aisdata.ais.dk/ for
January 2026. The chapters that work on a single day use January 20, 2026, and the lakehouse
chapter uses the whole month.

The cleaning rules are those of the MobilityLakehouse pipeline
(https://github.com/MobilityDB/MobilityLakehouse, `benchmark/planar/10_stage.sql`,
`20_clean.sql` and `25_segments.sql`, at the commit of `lakehouse.env`), written here for
PostgreSQL and MobilityDB. `check_duckdb.sh` runs that pipeline in DuckDB with MobilityDuck over
the same archives and checks that both keep the same reports and the same segments.

### Tables

| Table | Content |
|---|---|
| `AISInput` | The raw reports, with the 26 columns of the CSV files of the Danish Maritime Authority |
| `AISClean` | The reports kept by the cleaning, with every column of `AISInput`, the position in EPSG:25832 in `Geom`, and the number of the piece of the vessel's track in `Piece` |
| `Segments` | The stops (`Stationary`) and moves (`In motion`) of each piece, with their trajectory in EPSG:25832 in `Trip` and in longitude and latitude in `TripLonLat` |
| `Vessels` | One row per vessel with its static attributes, each the value it reports most often |
| `Ships` | One row per vessel with its trajectory (`Trip`, `TripLonLat`) and the speed over ground, course over ground, heading and rate of turn it reports (`SOG`, `COG`, `Heading`, `ROT`), as temporal values with a gap wherever the vessel is silent for more than 600 s |

### Rules

| Rule | A report is kept when |
|---|---|
| Transponder | it comes from a Class A transponder |
| Identity | its MMSI is between 200000000 and 799999999 and its first three digits are Maritime Identification Digits allocated to an administration (`itu_mid.csv`) |
| Study area | its longitude is between 3 and 16 and its latitude between 53 and 59 |
| Dimensions | its draught is at most 28.5 m, its width at most 75 m and its length at most 488 m, or the value is missing |
| Duplicates | it is the first of the reports of its vessel at its instant, ordered by latitude, longitude, ship type, speed over ground, navigational status and then every other column |
| Reachability | the last kept report of its vessel can reach it at 100 knots, walking forward and backward from a seed corroborated by most of the first eleven reports |
| Vessel | at most half of the reports of its vessel are unreachable from the report before them |

A silence of more than 600 s starts a new piece. A vessel becomes stopped when the speed of the
centroid of its positions over the next 600 s falls to 0.2 knots, and moving again when it
reaches 0.5 knots; a stopped run of at least 300 s is a stop.

### Software

- PostgreSQL 18 with PostGIS 3.6 and MobilityDB (the version of the chapter that uses the
  database).
- For `check_duckdb.sh`: git, and a DuckDB shell carrying the MobilityDuck extension
  (https://github.com/MobilityDB/MobilityDuck), named by the variable `DUCKDB_ENGINE`.

### Building the database

January 20, 2026 is the canonical day of the book: every chapter that uses AIS data works on
that day, except the lakehouse chapter (chapter 10), which uses the whole of January 2026.
`fetch_data.sh`, `build.sh` and `check_duckdb.sh` therefore take one argument, `day` (the
default) or `month`, and all three must be given the same one.

To build the database of the canonical day, which every chapter but chapter 10 needs:

    bash fetch_data.sh
    createdb ais
    bash build.sh
    DUCKDB_ENGINE=/path/to/duckdb bash check_duckdb.sh

To build the database of the whole month, for chapter 10:

    bash fetch_data.sh month
    createdb ais
    bash build.sh month
    DUCKDB_ENGINE=/path/to/duckdb bash check_duckdb.sh month

`fetch_data.sh` downloads the archives into `data/ais/` and the table of Maritime Identification
Digits into `data/`. The Danish Maritime Authority does not allow its data to be redistributed,
so the repository holds none of them. `build.sh` loads the archives into `AISInput` and runs
`ais_clean.sql`, `ais_segments.sql` and `ais_ships.sql`. On a laptop, the cleaning of one day
takes about 10 minutes, the segmentation about 40 minutes, since PostgreSQL recomputes the
average of each 600-second window, and the trajectories about 3 minutes. For January 20, 2026,
the database holds:

| Item | Count |
|---|--:|
| Raw reports | 17,630,815 |
| Clean reports | 9,374,915 |
| Vessels | 2,701 |
| Pieces | 14,703 |
| Segments | 20,515 |

and `check_duckdb.sh` prints, for both pipelines, the same fingerprints:

    clean 9374915 75bbc838f5ad9529d2fc78f62489fd19
    segments 20515 99cca523a7b98ddcbbba4b63f0af82c0

`ships_fingerprint.sql` gives the fingerprint of `Ships`, the table of trips that the chapters
query. The trips depend on the MobilityDB that builds them, since MobilityDB keeps an instant of a
trip exactly when it is not redundant; with MobilityDB master `96f10bdac8` it prints

    psql -d ais -At -f ships_fingerprint.sql
    ships|2701|8989892|14703|f4d6925b33d48cae2b88c50189b282d6

that is, 2,701 vessels, 8,989,892 instants and 14,703 sequences.
