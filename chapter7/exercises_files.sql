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

-- Exercise 7.5 of chapter 7, over the CSV file of the AIS reports of 2026-01-20 and the Parquet
-- file that values/section_duckdb.sql writes from it, without loading them into a table; the
-- '/.../AIS' directory of the chapter is ${AIS_DIR}. Run it with run_duckdb.sh, as the README says.
.mode markdown
.print == 1. the names and types inferred for the columns of the CSV file
DESCRIBE SELECT * FROM '${AIS_DIR}/aisdk-2026-01-20.csv';
.print == 2. the reports, the distinct vessels, and the reports without a position
SELECT COUNT(*) AS Reports, COUNT(DISTINCT MMSI) AS Vessels,
  COUNT(*) FILTER (WHERE Latitude = 91) AS NoPosition
FROM '${AIS_DIR}/aisdk-2026-01-20.csv';
.print == 3. the bytes of the whole Parquet file and of its column MMSI
SELECT SUM(total_compressed_size) AS AllBytes,
  SUM(total_compressed_size) FILTER (WHERE path_in_schema = 'MMSI') AS MmsiBytes
FROM parquet_metadata('${AIS_DIR}/ais.parquet');
.print == 3. the size and the encodings of each column, the largest first
SELECT path_in_schema AS Col, SUM(total_compressed_size) AS Bytes,
  string_agg(DISTINCT encodings) AS Encodings
FROM parquet_metadata('${AIS_DIR}/ais.parquet')
GROUP BY ALL ORDER BY Bytes DESC;
.print == 3. the average number of reports per second
SELECT COUNT(*) / COUNT(DISTINCT "# Timestamp") AS PerSecond
FROM '${AIS_DIR}/aisdk-2026-01-20.csv';
