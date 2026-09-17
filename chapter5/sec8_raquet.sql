-- Section 8: the depth under the vessel of Section 3 read from the bathymetry
-- stored as RaQuet tiles (converted by raquet-io, zoom 11, EPSG:3857) and
-- compared with the depth read from the PostGIS raster in EPSG:25832.
\pset footer off
\timing on
SET TimeZone = 'UTC';

\echo == tiles of zoom 11 crossed by the trip, and the depth read from them
DROP TABLE IF EXISTS DepthRaquet;
CREATE TABLE DepthRaquet AS
WITH Tiles AS (
  SELECT s.MMSI, array_agg(r.Tile) AS Tiles
  FROM Ships s, BathymetryRaquet r
  WHERE s.MMSI = 273277840 AND
    quadbin(r.Tile) IN (SELECT unnest(getValues(tquadbin(s.TripLonLat, 11))))
  GROUP BY s.MMSI )
SELECT s.MMSI, array_length(t.Tiles, 1) AS NumTiles,
  rasterTileValue(s.TripLonLat, t.Tiles) AS Depth
FROM Ships s JOIN Tiles t USING (MMSI);

SELECT NumTiles, duration(whenTrue(Depth #< 20)) AS Under20,
  numSpans(whenTrue(Depth #< 20)) AS Periods
FROM DepthRaquet;

\echo == the same question on the PostGIS raster
WITH VesselDepth AS (
  SELECT mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM Ships s, Bathymetry b
  WHERE s.MMSI = 273277840 AND ST_Intersects(b.Rast, trajectory(s.Trip)) )
SELECT duration(whenTrue(Depth #< 20)) AS Under20,
  numSpans(whenTrue(Depth #< 20)) AS Periods
FROM VesselDepth;

\echo == tiles in the table and tiles read
SELECT (SELECT count(*) FROM BathymetryRaquet) AS AllTiles,
  (SELECT NumTiles FROM DepthRaquet) AS TilesRead;
