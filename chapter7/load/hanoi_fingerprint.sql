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

-- The fingerprints of the Hanoi tables of chapter 7, in PostgreSQL (load/hanoi_pg.sql) or in
-- DuckDB (load/hanoi_duckdb.sql, load/hanoi_duckdb_csv.sql): the number of rows and the MD5 of
-- their keys, one line per row in a total order. A trip is keyed by its identifier, its vehicle,
-- its first and last instants in microseconds since 1970 and its number of instants; a
-- municipality by its identifier and its area in square meters rounded to the millimeter. The
-- last line is the length of the trips within the municipality of Soc Son.
--
--   psql -d hanoi -At -f load/hanoi_fingerprint.sql
--   duckdb -unsigned hanoi.duckdb -c "LOAD spatial" -c "LOAD '<mobilityduck extension>'" \
--     -c ".read load/hanoi_fingerprint.sql"

SELECT 'trips', COUNT(*), SUM(numInstants(Trip)), md5(string_agg(
  CAST(TripId AS text) || ',' || CAST(VehicleId AS text) || ',' ||
  CAST(CAST(EXTRACT(EPOCH FROM startTimestamp(Trip)) * 1000000 AS bigint) AS text) || ',' ||
  CAST(CAST(EXTRACT(EPOCH FROM endTimestamp(Trip)) * 1000000 AS bigint) AS text) || ',' ||
  CAST(numInstants(Trip) AS text), ';' ORDER BY TripId))
FROM Trips;

SELECT 'municipalities', COUNT(*), md5(string_agg(
  CAST(MunicipalityId AS text) || ',' ||
  CAST(CAST(round(ST_Area(MunicipalityGeo) * 1000) AS bigint) AS text), ';'
  ORDER BY MunicipalityId))
FROM Municipalities;

SELECT 'socson', COUNT(*), round(CAST(SUM(ST_Length(ST_Intersection(t.Trajectory,
  m.MunicipalityGeo))) / 1000 AS numeric), 3)
FROM Trips t, Municipalities m
WHERE m.MunicipalityName = 'Huyện Sóc Sơn' AND ST_Intersects(t.Trajectory, m.MunicipalityGeo);
