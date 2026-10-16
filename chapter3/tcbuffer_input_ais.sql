-- -----------------------------------------------------------------------------
-- The input of the underwater-noise case study of Chapter 3 for January 20,
-- 2026: the table AISInputTarget that tcbuffer_trajectories() of
-- tcbuffer_load.sql reads, built from the cleaned reports of the table AISClean
-- of the AIS database of the book (ais/ of this repository), whose positions
-- Geom are in EPSG:25832. The values that stand for a missing value are set to
-- NULL as the table AISInputFiltered of tcbuffer_input() sets them.
--
-- Usage: psql -d <database> -f tcbuffer_input_ais.sql, on a database holding
-- AISClean; tcbuffer_load_ais.sh runs it.
-- -----------------------------------------------------------------------------
SET TIMEZONE TO 'UTC';
DROP TABLE IF EXISTS AISInputTarget;
CREATE TABLE AISInputTarget AS
SELECT DISTINCT ON (MMSI, T) MMSI,
  CASE WHEN IMO = 'Unknown' THEN NULL ELSE IMO END AS IMO,
  Name,
  CASE WHEN ShipType = 'Undefined' OR ShipType = 'Other' THEN NULL ELSE ShipType END AS ShipType,
  CASE WHEN CargoType = 'No additional information' THEN NULL ELSE CargoType END AS CargoType,
  Length, T, SOG, COG, Geom
FROM AISClean
ORDER BY MMSI, T;
SELECT count(*) FROM AISInputTarget;
