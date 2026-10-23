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

-- The plan of chapter 7's figure mduckq14plan: Query que:close300 over ${CH7_DB_DIR}/ships.duckdb, one thread.
LOAD spatial;
LOAD '${MOBILITYDUCK_EXTENSION}';
SET threads=1;
.output ${CH7_PLAN_DIR}/plan_close300.txt
EXPLAIN ANALYZE WITH Timespan(Period) AS (
  SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
  SELECT MMSI, atTime(s.Trip, t.Period)
  FROM Ships s TABLESAMPLE RESERVOIR (300 ROWS) REPEATABLE (1),
    Timespan t
  WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
TimeClosestShips(MMSI1, MMSI2, ClosestDist, TimeAtClosestDist, Trip1, Trip2) AS (
  SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)),
    startTimestamp(atMin(s1.Trip <-> s2.Trip)), s1.Trip, s2.Trip
  FROM TimeShips s1, TimeShips s2
  WHERE s1.MMSI < s2.MMSI AND CASE WHEN eDwithin(s1.Trip, s2.Trip, 300)
    THEN startValue(atMin(s1.Trip <-> s2.Trip)) < 300 END )
SELECT t.MMSI1, t.MMSI2, t.ClosestDist, t.TimeAtClosestDist,
  valueAtTimestamp(Trip1, TimeAtClosestDist) AS Point1,
  valueAtTimestamp(Trip2, TimeAtClosestDist) AS Point2
FROM TimeClosestShips t;
.output
