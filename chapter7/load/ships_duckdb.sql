-- The listing "Table Creation, Population, and Indexing" of chapter 7, with {conn_str} the
-- PostgreSQL database ais, ${PG_AIS} and the extension the one of the MobilityDuck CI.
INSTALL spatial FROM core_nightly;
INSTALL postgres;
INSTALL '${MOBILITYDUCK_EXTENSION}';
LOAD spatial;
LOAD mobilityduck;
LOAD postgres;

CREATE OR REPLACE TABLE ships (MMSI integer, Trip tgeompoint, SOG tfloat,
 COG tfloat);

INSERT INTO ships
SELECT MMSI, Trip, SOG, COG
FROM postgres_scan('${PG_AIS}', 'public', 'ships');

SET threads=1;
SET memory_limit='7000MB';

SELECT COUNT(*) FROM ships;

ALTER TABLE ships ADD column trajectory geometry;
UPDATE ships set trajectory = trajectory(trip);
CREATE INDEX rtree_trip ON Ships USING RTREE(trajectory);
SELECT count(*), count(trajectory), sum(numInstants(Trip)) FROM ships;
