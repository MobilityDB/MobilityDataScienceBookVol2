WITH Target AS (
  SELECT Geom, t
  FROM AISInput
  WHERE MMSI = 219015442
  ORDER BY t DESC
  LIMIT 1 )
SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom
FROM AISInput other, Target t
WHERE other.MMSI <> 219015442 AND
  ST_DISTFN(other.Geom, t.Geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60;
