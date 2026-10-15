-- Load the raw AIS reports of January 20, 2026 into the table AISInput of a DuckDB database, as
-- the section "DuckDB SQL Features" of the chapter does, with the point geometry Geom built from
-- the longitude and the latitude of each report. The file aisdk-2026-01-20.csv is read from the
-- working directory of the DuckDB shell.
LOAD spatial;
SET TimeZone = 'UTC';
SET geometry_always_xy = true;
CREATE OR REPLACE TABLE AISInput AS
SELECT *, ST_Point(Longitude, Latitude) AS Geom
FROM read_csv('aisdk-2026-01-20.csv', header = true,
  timestampformat = '%d/%m/%Y %H:%M:%S',
  names = ['T', 'TypeOfMobile', 'MMSI', 'Latitude', 'Longitude', 'NavigationalStatus',
    'ROT', 'SOG', 'COG', 'Heading', 'IMO', 'CallSign', 'Name', 'ShipType', 'CargoType',
    'Width', 'Length', 'TypeOfPositionFixingDevice', 'Draught', 'Destination', 'ETA',
    'DataSourceType', 'SizeA', 'SizeB', 'SizeC', 'SizeD']);
SELECT COUNT(*) FROM AISInput;
