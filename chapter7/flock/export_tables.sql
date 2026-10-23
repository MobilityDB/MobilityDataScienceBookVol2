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

-- The three tables that flock_pipelines.sql reads, written as Parquet files into this directory
-- from the Hanoi database of DuckDB that load/hanoi_duckdb.sql builds, geometries as WKT in
-- EPSG:3857:
--
--   ../run_duckdb.sh "$CH7_DB_DIR/hanoi.duckdb" export_tables.sql
LOAD spatial;
COPY (SELECT PointId, ST_AsText(Geom) AS Geom FROM Points ORDER BY PointId) TO 'points.parquet';
COPY (SELECT MunicipalityId, MunicipalityName, ST_AsText(MunicipalityGeo) AS MunicipalityGeo
  FROM Municipalities ORDER BY MunicipalityId) TO 'municipalities.parquet';
COPY (SELECT * FROM Vehicles ORDER BY VehicleId) TO 'vehicles.parquet';
