## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 5: Rasters and Temporal Tessellations

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter reads fields (bathymetry, waves, temperature, salinity, wind) along
the trips of vessels, and aggregates the trips over discrete global grids. The
scripts run against **PostgreSQL 18, PostGIS 3.6 and MobilityDB 1.4** built with
all its families, GDAL 3.8, and QGIS 3.40 for the figures.

Every geometry and raster is transformed ONCE, when the data are prepared, to
EPSG:25832, or kept in longitude and latitude in the columns whose name ends in
`LonLat`; no query transforms a geometry.

### Datasets

The scripts read the datasets from a directory `data/` below the working
directory, or from the directory named by the environment variable `DATA`, and
connect to PostgreSQL through the usual environment variables (`PGDATABASE`,
`PGHOST`, ...). None of the datasets is redistributed here.

- **AIS**: one day of the Danish Maritime Authority, 2026-01-20,
  http://aisdata.ais.dk/aisdk-2026-01-20.zip
- **Bathymetry**: Denmark's Depth Model, 50 m, layer `ddm_50m.dybde`, from the
  Danish Geodata Agency (https://eng.gst.dk/danish-hydrographic-office/denmark-depth-model).
  Attribution: "Indeholder data fra Geodatastyrelsen, Danmarks Dybdemodel, 50 m
  opløsning"; the model is not suitable for navigation.
- **Ports and protected areas**: the files `port.csv` and
  `natural_areas.csv.gz` used by chapter 3.
- **Ocean model fields**: the Copernicus Marine Service hourly products of the
  Baltic Sea (`BALTICSEA_ANALYSISFORECAST_PHY_003_006`,
  `BALTICSEA_ANALYSISFORECAST_WAV_003_010`) and of the North West Shelf
  (`NWSHELF_ANALYSISFORECAST_PHY_004_013`, `NWSHELF_ANALYSISFORECAST_WAV_004_014`).
  They require a free account and the Copernicus Marine Toolbox:

      pip install copernicusmarine==2.4.1
      copernicusmarine login        # the username is the e-mail of the account
      B="-x 3 -X 16.5 -y 53.5 -Y 58.5 -t 2026-01-20T00:00:00 -T 2026-01-21T00:00:00 -o data/cmems"
      copernicusmarine subset -i cmems_mod_bal_phy_anfc_PT1H-i -v thetao -v so -v sla -v mlotst --minimum-depth 0 --maximum-depth 1 $B -f bal_phy_20260120.nc
      copernicusmarine subset -i cmems_mod_bal_wav_anfc_PT1H-i -v VHM0 -v VMDR $B -f bal_wav_20260120.nc
      copernicusmarine subset -i cmems_mod_nws_phy-sst_anfc_1.5km-2D_PT1H-i -v thetao $B -f nws_sst_20260120.nc
      copernicusmarine subset -i cmems_mod_nws_phy-sss_anfc_1.5km-2D_PT1H-i -v so $B -f nws_sss_20260120.nc
      copernicusmarine subset -i cmems_mod_nws_wav_anfc_1.5km_PT1H-i -v VHM0 -v VMDR $B -f nws_wav_20260120.nc

  Attribution: "Generated using E.U. Copernicus Marine Service Information".
- **Wind**: ERA5 hourly data on single levels, 10 m wind components, from the
  Copernicus Climate Data Store, which requires an account, an API key in
  `~/.cdsapirc`, and accepting the terms of the dataset on its page. The
  request of the scripts is the area [58.5, 3, 53.5, 16.5] for the days
  2026-01-20 and 2025-01-01, written as `data/era5/era5_wind10m_<YYYYMMDD>.nc`.
  Licence CC-BY-4.0.

### Loading

    psql -f ais_load.sql
    unzip -p aisdk-2026-01-20.zip | PGOPTIONS='-c datestyle=ISO,DMY' psql -c "\copy AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG, COG, Heading, IMO, CallSign, Name, ShipType, CargoType, Width, Length, TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType, SizeA, SizeB, SizeC, SizeD) FROM STDIN CSV HEADER"
    psql -f ais_pipeline.sql
    psql -f load_aux_tables.sql

ais_load.sql and ais_pipeline.sql: the input table of the AIS day, and its
cleaning into the tables `AISClean` and `AISNoJump` and the trips of the table
`Ships`, split where a vessel is silent for more than 3 minutes or moves more
than one nautical mile between two positions.

The bathymetry is reprojected once and loaded as a tiled raster:

    gdalwarp -t_srs EPSG:25832 -tr 50 50 -tap -r near ddm_50m.dybde.tiff data/ddm/ddm_50m_25832.tif
    raster2pgsql -s 25832 -t 256x256 -I -C -M -F data/ddm/ddm_50m_25832.tif public.Bathymetry | psql

The hourly fields are merged, reprojected once, and loaded as tables
`(ValidTime, Rast)` with one row per tile of each hourly step:

    bash prep_waves.sh && bash load_waves.sh
    bash prep_fields.sh
    bash load_field.sh data/cmems/sst25832 SurfaceTemperature
    bash load_field.sh data/cmems/sss25832 SurfaceSalinity
    bash load_field.sh data/era5/wind25832 WindSpeed 50x50

prep_waves.sh and prep_fields.sh keep, for each hour, the value of the Baltic
Sea product where it has one and the value of the North West Shelf product
elsewhere, on a 1 km grid with nearest-neighbour resampling. prep_wind.sh
computes the wind speed of ERA5 for any day on a 5 km grid.

### Scripts of the Sections

- sec2_postgis_raster.sql: the PostGIS raster tutorial (values, zonal
  statistics, reclassification, map algebra).
- sec3_postgis_only.sql and sec3_depth_under_vessel.sql: the depth under a
  vessel with PostGIS alone and with MobilityDB.
- sec4_field_along_trip.sql: the synthetic rasters of the section on reading
  fields along trajectories, including fields that change over time.
- sec5_sec6_cells.sql, sec6_filter.sql and sec6_nesting.sql: the grids, the
  temporal cells of a trip, the cells as a filter, and the nesting of the cells
  across resolutions.
- sec8_clearance.sql and sec8_clearance_underway.sql: under-keel clearance,
  with the vessels under way defined by the speed over ground they report.
- sec8_seastate.sql and sec8_speed_waves.sql: the wave height along the trips
  and the speed of the vessels in higher waves.
- sec8_noise_depth_one.sql, sec8_noise_depth_radius.sql,
  sec8_noise_depth_all.sql and sec8_noise_env_all.sql: the underwater noise of
  chapter 3 with spreading depending on the depth and ambient noise depending on
  the wind. They run on the database of chapter 3 (AIS day 2025-01-01) with the
  tables `Bathymetry` and `WindSpeed` of that day added:

      bash prep_wind.sh 20250101
      bash load_field.sh data/era5/wind25832_20250101 WindSpeed 50x50 20250101

- sec8_density.sql and sec8_rollup.sql: vessel-hours per H3 cell, and the
  roll-up of resolution 7 to resolution 5.
- sec8_raquet.sql: the bathymetry stored as RaQuet tiles. The tiles are
  produced by the official converter and loaded with load_raquet.py:

      pip install raquet-io==0.9.0
      raquet-io convert raster data/ddm/ddm_50m_25832.tif data/raquet/bathymetry.parquet --overviews none --resampling near
      python3 load_raquet.py data/raquet/bathymetry.parquet BathymetryRaquet "dbname=tess"

- sec8_raquet_series.sql: tiles that carry a validity period, read by joining
  them on the cells of the trip and on the overlap of the periods. It gives the
  tiles of the bathymetry the two halves of the trip as their periods, and the
  reading merges into the reading of the whole trip.

- exercises.sql: the answers of the exercises.

### Figures

The directory figures/ holds the scripts that draw the figures of the chapter
with QGIS: render_map.py renders a job file (the layers, their styles, the
extent and the size), render.sh calls it with the Python of QGIS (set
`QGIS_PY`, whose default is the QGIS 3.40 installation of Windows called from
WSL), and the export scripts write the layers of each figure from the database
as GeoPackage files.
