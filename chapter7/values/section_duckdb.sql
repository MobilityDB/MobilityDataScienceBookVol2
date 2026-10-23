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

-- The listings of Sect. "DuckDB" of chapter 7, in their order, over the AIS reports of
-- 2026-01-20; the '/.../AIS' directory of the chapter is ${AIS_DIR}.
-- Run with the DuckDB v1.5.5 shell through envsubst, as the README says; the spatial extension is the
-- one of core_nightly, as the chapter installs it.
.timer on
.mode markdown
INSTALL spatial FROM core_nightly;
LOAD spatial;
.print == extensions
SELECT extension_name, loaded, installed
FROM duckdb_extensions()
ORDER BY installed DESC, loaded DESC;
.print == load
SET geometry_always_xy = true;
CREATE OR REPLACE TABLE AISInput AS
SELECT *, ST_Point(Longitude, Latitude) AS Geom
FROM read_csv('${AIS_DIR}/aisdk-2026-01-20.csv', header = true,
  timestampformat = '%d/%m/%Y %H:%M:%S',
  names = ['T', 'TypeOfMobile', 'MMSI', 'Latitude', 'Longitude',
    'NavigationalStatus', 'ROT', 'SOG', 'COG', 'Heading', 'IMO', 'CallSign',
    'Name', 'ShipType', 'CargoType', 'Width', 'Length',
    'TypeOfPositionFixingDevice', 'Draught', 'Destination', 'ETA',
    'DataSourceType', 'SizeA', 'SizeB', 'SizeC', 'SizeD']);
DESCRIBE AISInput;
.print == exclude
SELECT * EXCLUDE (SOG) FROM AISInput LIMIT 2;
.print == columns
SELECT MAX(COLUMNS('L.*')) FROM AISInput;
.print == alias
SELECT SOG > 0.5 AS IsMoving, date_trunc('month', T) AS ReportMonth,
  AVG(ROT) AS AvRot
FROM AISInput
WHERE IsMoving = TRUE
GROUP BY IsMoving, ReportMonth
HAVING AvRot > 5;
.print == groupbyall
SELECT COUNT(*) FROM (
SELECT MMSI, date_trunc('day', T) AS ReportDay, round(SUM(SOG) / 24, 2) AS TotalSogPerDay,
  round(AVG(COG), 2) AS AvgCogPerDay
FROM AISInput
GROUP BY ALL);
.print == pivot1
SELECT *
FROM (
  SELECT MMSI, date_trunc('day', T) AS ReportDay,  ShipType, SOG
  FROM AISInput
  WHERE MMSI = 258656000)
PIVOT (AVG(SOG) FOR ShipType IN ('Cargo', 'Tanker', 'Passenger', 'Fishing') )
ORDER BY ReportDay;
SELECT Name, ShipType, COUNT(*), COUNT(DISTINCT Geom::VARCHAR) FROM AISInput WHERE MMSI = 258656000 GROUP BY ALL;
.print == pivot2
SELECT *
FROM (
  SELECT MMSI, IF(hour(T) < 12, 'AM', 'PM') AS HalfDay, SOG
  FROM AISInput )
PIVOT (
  round(SUM(SOG)) AS total,
  MAX(SOG) AS bestSOG
  FOR HalfDay IN ('AM', 'PM')
)
ORDER BY MMSI
LIMIT 4;
SELECT MMSI, TypeOfMobile, COUNT(*) FROM AISInput WHERE MMSI IN (3638, 261505, 2190045) GROUP BY ALL ORDER BY ALL;
.print == files
SELECT filename, COUNT(*)
FROM read_csv_auto('${AIS_DIR}/*.csv', filename=true)
GROUP BY ALL
ORDER BY ALL;
.print == totrows
WITH TotRows AS (
  SELECT filename, COUNT(*) as Qty
  FROM read_csv_auto ('${AIS_DIR}/*.csv', filename=true)
  GROUP BY ALL
  ORDER BY ALL )
SELECT SUM(Qty) FROM TotRows;
.print == topmmsi
SELECT MMSI, COUNT(*) AS totShips
FROM '${AIS_DIR}/*.csv'
GROUP BY ALL
ORDER BY totShips DESC
LIMIT 2;
.print == parquet
SET memory_limit = '2GB';
COPY(SELECT * FROM '${AIS_DIR}/*.csv')
TO '${AIS_DIR}/ais.parquet'
(FORMAT PARQUET, CODEC 'SNAPPY', ROW_GROUP_SIZE 100000);
RESET memory_limit;
.print == parquetquery
SELECT COUNT(*) FROM (SELECT MMSI, COUNT(*) FROM '${AIS_DIR}/ais.parquet' GROUP BY ALL);
