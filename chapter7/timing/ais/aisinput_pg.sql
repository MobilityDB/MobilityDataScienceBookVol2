-- Add to the table AISInput of the AIS database of the book (built by ais/build.sh of this
-- repository) the point geometry Geom in longitude and latitude that the PostGIS queries of
-- the section "Querying DuckDB" read, by rewriting the table.
\set ON_ERROR_STOP on
CREATE TABLE AISInputG AS
SELECT *, ST_SetSRID(ST_MakePoint(Longitude, Latitude), 4326)::geometry(Point, 4326) AS Geom
FROM AISInput;
DROP TABLE AISInput;
ALTER TABLE AISInputG RENAME TO AISInput;
VACUUM ANALYZE AISInput;
