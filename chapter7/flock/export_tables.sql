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
