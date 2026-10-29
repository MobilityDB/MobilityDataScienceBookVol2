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

-- The plan of chapter 7's figure index_plan: the listings of the R-tree example over the table
-- TestGeo, and EXPLAIN of its query, as the DuckDB v1.5.6 shell prints it.
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
