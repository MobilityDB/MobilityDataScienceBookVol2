-- Section 6: a relationship computed on the cells of a trip is a necessary
-- condition for the relationship of the trip itself. Preprocessing adds the
-- lon/lat geometry of the protected areas once.
\pset footer off
\timing on
ALTER TABLE NaturalAreas ADD COLUMN IF NOT EXISTS GeomLonLat geometry;
UPDATE NaturalAreas SET GeomLonLat = ST_Transform(Geom, 4326) WHERE GeomLonLat IS NULL;

DROP TABLE IF EXISTS CellFilter;
CREATE TABLE CellFilter AS
SELECT s.MMSI, n.Id,
  eIntersects(s.TripLonLat, n.GeomLonLat) AS TripMeets,
  eIntersects(th3index(s.TripLonLat, 7), n.GeomLonLat) AS CellsMeet
FROM (SELECT * FROM Ships ORDER BY MMSI LIMIT 200) s, NaturalAreas n
WHERE n.Realm IN ('Marine', 'Coastal')
  AND s.TripLonLat && stbox(n.GeomLonLat);

SELECT count(*) AS Pairs,
  count(*) FILTER (WHERE TripMeets) AS TripMeets,
  count(*) FILTER (WHERE CellsMeet) AS CellsMeet,
  count(*) FILTER (WHERE TripMeets AND NOT CellsMeet) AS TripOnly,
  count(*) FILTER (WHERE CellsMeet AND NOT TripMeets) AS CellsOnly
FROM CellFilter;
