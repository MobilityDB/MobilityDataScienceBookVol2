-- The plan of chapter 7's figure index_plan: the listings of the R-tree example over the table
-- TestGeo, and EXPLAIN of its query, as the DuckDB v1.5.5 shell prints it.
LOAD '${MOBILITYDUCK_EXTENSION}';
CREATE TABLE TestGeo("times" timestamptz, "box" stbox);
CREATE INDEX rtree_stbox ON TestGeo USING TRTREE(box);
INSERT INTO TestGeo
SELECT ('2025-08-11 12:00:00'::timestamp + INTERVAL (i || ' minutes')) AS times,
  ('STBOX X((' || (i * 1.0)::DECIMAL(10,2) || ',' ||
    (i * 1.0)::DECIMAL(10,2) || '),(' ||
    (i * 1.0 + 0.5)::DECIMAL(10,2) || ',' ||
    (i * 1.0 + 0.5)::DECIMAL(10,2) || '))') AS stbox_data
FROM generate_series(1, 1000) AS t(i);
.output ${CH7_PLAN_DIR}/plan_index.txt
EXPLAIN SELECT * FROM TestGeo
WHERE box && STBOX('STBOX X((1000.0,1000.0), (1100.0,1100.0))');
.output
