WITH Latest AS (
  SELECT MMSI, geom, t
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI
      ORDER BY t DESC) AS RowNo
    FROM AISInput )
  WHERE RowNo = 1 ),
Target AS (
  SELECT MMSI, geom, t
  FROM Latest
  WHERE MMSI = 219015442 )
SELECT o.MMSI, ST_AsText(o.geom) AS geom,
  ST_DISTFN(o.geom, t.geom) AS Distance,
  ABS(EXTRACT(EPOCH FROM (o.t - t.t))) AS TimeDiff
FROM Latest o JOIN Target t ON o.MMSI <> t.MMSI
WHERE ST_DISTFN(o.geom, t.geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (o.t - t.t))) <= 60
ORDER BY Distance
LIMIT 5;
