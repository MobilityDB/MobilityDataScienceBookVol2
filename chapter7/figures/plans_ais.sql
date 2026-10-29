/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- The plans of chapter 7's figures queryduckdbproc_a (Query 2), queryduckdbproc_b (Query 3) and
-- queryprocplan8 (Query 8), over ${CH7_DB_DIR}/ais.duckdb, as the DuckDB v1.5.6 shell prints them.
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
