-- Cleaning pipeline for one Danish AIS day, in PostgreSQL with MobilityDB.
--
-- Load first (one command, from the zip, with the workshop's AISInput columns):
--   unzip -p aisdk-2026-01-20.zip | PGOPTIONS='-c datestyle=ISO,DMY' psql -d aisdk -c
--     "\copy AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG,
--      COG, Heading, IMO, CallSign, Name, ShipType, CargoType, Width, Length,
--      TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType,
--      SizeA, SizeB, SizeC, SizeD) FROM STDIN CSV HEADER"
--
-- Then: psql -d aisdk -f aisdk_pipeline.sql

SET TimeZone = 'UTC';          -- AIS timestamps are UTC
SET work_mem = '512MB';

-- 1. Positions a trajectory can use.
--    Ship messages only (Class A, ship MMSI range), inside the EPSG:25832 window, one row per
--    ship and instant. The ORDER BY makes the kept row the same on every run. Impossible
--    dimensions and speed readings (102.3 kn is AIS "not available") are blanked, not dropped:
--    the position itself is still valid.
DROP TABLE IF EXISTS AISClean CASCADE;
CREATE TABLE AISClean AS
SELECT DISTINCT ON (MMSI, T)
  MMSI, T,
  CASE WHEN SOG <= 60 THEN SOG END AS SOG,
  COG, ShipType,
  CASE WHEN Length  <= 488  THEN Length  END AS Length,
  CASE WHEN Width   <= 75   THEN Width   END AS Width,
  CASE WHEN Draught <= 28.5 THEN Draught END AS Draught,
  ST_Transform(ST_SetSRID(ST_MakePoint(Longitude, Latitude), 4326), 25832) AS Geom
FROM AISInput
WHERE TypeOfMobile = 'Class A'
  AND MMSI BETWEEN 200000000 AND 799999999
  AND Longitude BETWEEN -16.1 AND 32.88 AND Latitude BETWEEN 40.18 AND 84.17
ORDER BY MMSI, T, SOG, Latitude, Longitude;

-- 2. Each ship's speed limit: its own 99.9th-percentile reported speed plus 25 %, kept between
--    15 and 100 knots. A ship with fewer than 100 speed readings gets 100 knots.
DROP TABLE IF EXISTS ShipSpeed;
CREATE TABLE ShipSpeed AS
SELECT MMSI,
  CASE WHEN count(SOG) >= 100
       THEN LEAST(100, GREATEST(15, 1.25 * percentile_cont(0.999) WITHIN GROUP (ORDER BY SOG)))
       ELSE 100 END AS VMaxKnots
FROM AISClean
GROUP BY MMSI;

-- 3. Jumps. A position is a spike when it cannot be reached from EITHER neighbour at the ship's
--    speed limit, while the two neighbours can reach each other. Distances are metres in
--    EPSG:25832; 500 m absorbs GPS error; knots * 0.514444 = m/s. The first and last position
--    of a ship have a single neighbour and are kept.
DROP TABLE IF EXISTS AISNoJump;
CREATE TABLE AISNoJump AS
WITH N AS (
  SELECT C.*, S.VMaxKnots * 0.514444 AS VMax,
    LAG(Geom)  OVER W AS PGeom, LAG(T)  OVER W AS PT,
    LEAD(Geom) OVER W AS NGeom, LEAD(T) OVER W AS NT
  FROM AISClean C JOIN ShipSpeed S USING (MMSI)
  WINDOW W AS (PARTITION BY MMSI ORDER BY T))
SELECT MMSI, T, SOG, COG, ShipType, Length, Width, Draught, Geom
FROM N
WHERE (ST_Distance(PGeom, Geom)  > VMax * EXTRACT(EPOCH FROM T  - PT) + 500 AND
       ST_Distance(Geom, NGeom)  > VMax * EXTRACT(EPOCH FROM NT - T)  + 500 AND
       ST_Distance(PGeom, NGeom) <= VMax * EXTRACT(EPOCH FROM NT - PT) + 500) IS NOT TRUE;

-- 4. Trajectories: one temporal point per ship, split where the ship is silent for more than
--    3 minutes or moves more than 1 nautical mile between two positions, so a gap is a hole in
--    the sequence set, never a straight line drawn across it.
DROP TABLE IF EXISTS Ships;
CREATE TABLE Ships(MMSI, Trip) AS
SELECT MMSI,
  tgeompointSeqSetGaps(array_agg(tgeompoint(Geom, T) ORDER BY T),
                       interval '3 minutes', 1852.0)
FROM AISNoJump
GROUP BY MMSI;

-- What each step did.
SELECT 'input rows' AS step, count(*) AS n FROM AISInput
UNION ALL SELECT '1. usable positions', count(*) FROM AISClean
UNION ALL SELECT '2. ships', count(*) FROM ShipSpeed
UNION ALL SELECT '3. jumps removed',
  (SELECT count(*) FROM AISClean) - (SELECT count(*) FROM AISNoJump)
UNION ALL SELECT '4. trajectories', count(*) FROM Ships
UNION ALL SELECT '4. sequences', sum(numSequences(Trip)) FROM Ships;
