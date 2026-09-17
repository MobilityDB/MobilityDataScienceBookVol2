-- Section 6: whether the parents of the cells of a trip at a fine resolution are
-- the cells of the trip at the coarser one, for H3 (aperture 7) and QUADBIN
-- (aperture 4), on the first 200 vessels of the AIS day.
\pset footer off
\timing on
DROP TABLE IF EXISTS Nesting;
CREATE TABLE Nesting AS
SELECT MMSI,
  getValues(th3index(TripLonLat, 7)) AS H3Coarse,
  getValues(cellToParent(th3index(TripLonLat, 9), 7)) AS H3Parents,
  getValues(tquadbin(TripLonLat, 13)) AS QbCoarse,
  getValues(cellToParent(tquadbin(TripLonLat, 15), 13)) AS QbParents
FROM (SELECT * FROM Ships ORDER BY MMSI LIMIT 200) s;

SELECT count(*) AS Vessels,
  count(*) FILTER (WHERE H3Coarse <> H3Parents) AS H3Differ,
  count(*) FILTER (WHERE QbCoarse <> QbParents) AS QbDiffer
FROM Nesting;

SELECT MMSI, numValues(H3Coarse) AS Coarse, numValues(H3Parents) AS Parents,
  numValues(H3Coarse - H3Parents) AS MissedByParents,
  numValues(H3Parents - H3Coarse) AS ExtraInParents
FROM Nesting
WHERE H3Coarse <> H3Parents
ORDER BY numValues(H3Coarse - H3Parents) DESC
LIMIT 10;
