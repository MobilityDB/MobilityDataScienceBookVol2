WITH Latest AS (
  SELECT MMSI, geom, t
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI
      ORDER BY t DESC) AS RowNo
    FROM AISInput )
  WHERE RowNo = 1 ),
Neighbors AS (
  SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2
  FROM Latest l1, Latest l2
  WHERE l1.MMSI <> l2.MMSI AND
    ST_DISTFN(l1.Geom, l2.Geom) <= 1000 AND
    ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60 )
SELECT l.MMSI, ST_AsText(l.Geom) AS Geom, COUNT(n.MMSI2) AS NeighborCount
FROM Latest l LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1
GROUP BY l.MMSI, l.Geom
ORDER BY NeighborCount DESC;
