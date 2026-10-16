-- The plans of chapter 7's figures queryduckdbproc_a (Query 2), queryduckdbproc_b (Query 3) and
-- queryprocplan8 (Query 8), over ${CH7_DB_DIR}/ais.duckdb, as the DuckDB v1.5.5 shell prints them.
LOAD spatial;
SET geometry_always_xy = true;
.output ${CH7_PLAN_DIR}/plan_q2.txt
EXPLAIN ANALYZE SELECT MMSI, COUNT(*) AS MessageCount FROM AISInput GROUP BY MMSI ORDER BY MessageCount DESC;
.output ${CH7_PLAN_DIR}/plan_q3.txt
EXPLAIN ANALYZE SELECT MMSI, MIN(t) AS FirstSeen, MAX(t) AS LastSeen FROM AISInput GROUP BY MMSI ORDER BY LastSeen;
.output ${CH7_PLAN_DIR}/plan_q8.txt
EXPLAIN ANALYZE WITH Target AS (
  SELECT Geom, t
  FROM AISInput
  WHERE MMSI = 219015442
  ORDER BY t DESC
  LIMIT 1 )
SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom
FROM AISInput other, Target t
WHERE other.MMSI <> 219015442 AND
  ST_Distance_Sphere(other.Geom, t.Geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60;
.output
