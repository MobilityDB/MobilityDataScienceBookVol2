-- The numbers chapter 7 prints about Queries 8 to 10 of Sect. "Querying DuckDB", over
-- ${CH7_DB_DIR}/ais.duckdb with the DuckDB v1.5.5 shell, as bench.py runs them.
LOAD spatial;
SET geometry_always_xy = true;
.print == q8 target
SELECT MMSI, Name, ShipType, t, NavigationalStatus FROM AISInput WHERE MMSI = 219015442 ORDER BY t DESC LIMIT 1;
.print == q8 result: rows, distinct reports, vessels
WITH Target AS (SELECT Geom, t FROM AISInput WHERE MMSI = 219015442 ORDER BY t DESC LIMIT 1),
R AS (SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom FROM AISInput other, Target t
  WHERE other.MMSI <> 219015442 AND ST_Distance_Sphere(other.Geom, t.Geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60)
SELECT count(*), count(DISTINCT (MMSI, t, Geom)), count(DISTINCT MMSI) FROM R;
.print == q8 plan
EXPLAIN ANALYZE WITH Target AS (SELECT Geom, t FROM AISInput WHERE MMSI = 219015442 ORDER BY t DESC LIMIT 1)
SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom FROM AISInput other, Target t
WHERE other.MMSI <> 219015442 AND ST_Distance_Sphere(other.Geom, t.Geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60;
.print == q9 distribution
WITH Latest AS (SELECT MMSI, geom, t FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI ORDER BY t DESC) AS RowNo FROM AISInput) WHERE RowNo = 1),
Neighbors AS (SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2 FROM Latest l1, Latest l2 WHERE l1.MMSI <> l2.MMSI AND ST_Distance_Sphere(l1.Geom, l2.Geom) <= 1000 AND ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60),
C AS (SELECT l.MMSI, COUNT(n.MMSI2) AS NeighborCount FROM Latest l LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1 GROUP BY l.MMSI)
SELECT count(*) FILTER (WHERE NeighborCount = 0) AS none, count(*) FILTER (WHERE NeighborCount BETWEEN 1 AND 2) AS one_two,
  count(*) FILTER (WHERE NeighborCount BETWEEN 3 AND 5) AS three_five, count(*) FILTER (WHERE NeighborCount >= 6) AS six_more,
  max(NeighborCount) AS maxn, (SELECT count(*) FROM Neighbors) AS pairs FROM C;
.print == q9 plan
EXPLAIN ANALYZE WITH Latest AS (SELECT MMSI, geom, t FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI ORDER BY t DESC) AS RowNo FROM AISInput) WHERE RowNo = 1),
Neighbors AS (SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2 FROM Latest l1, Latest l2 WHERE l1.MMSI <> l2.MMSI AND ST_Distance_Sphere(l1.Geom, l2.Geom) <= 1000 AND ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60)
SELECT l.MMSI, ST_AsText(l.Geom) AS Geom, COUNT(n.MMSI2) AS NeighborCount FROM Latest l LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1 GROUP BY l.MMSI, l.Geom ORDER BY NeighborCount DESC;
.print == q10
WITH Latest AS (SELECT MMSI, geom, t FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI ORDER BY t DESC) AS RowNo FROM AISInput) WHERE RowNo = 1),
Target AS (SELECT MMSI, geom, t FROM Latest WHERE MMSI = 219015442)
SELECT o.MMSI, ST_AsText(o.geom) AS geom, round(ST_Distance_Sphere(o.geom, t.geom), 2) AS Distance, ABS(EXTRACT(EPOCH FROM (o.t - t.t))) AS TimeDiff
FROM Latest o JOIN Target t ON o.MMSI <> t.MMSI
WHERE ST_Distance_Sphere(o.geom, t.geom) <= 1000 AND ABS(EXTRACT(EPOCH FROM (o.t - t.t))) <= 60
ORDER BY Distance LIMIT 5;
