-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
--
-- The numbers the text of the underwater-noise case study quotes and no
-- listing prints
--
-- Reads the AIS database of the book after ships_noise.sql, and the tables
-- Exposure and Encounter built by tcbuffer_case_study.sql. Run
-- after that script:
--   psql -d ais -f text_numbers.sql
-------------------------------------------------------------------------------

\timing on
SET TimeZone = 'UTC';

-------------------------------------------------------------------------------
-- The vessels of the day whose noise is computed, and the length and the
-- period under way of the fishing vessel
-------------------------------------------------------------------------------

SELECT COUNT(*) AS Ships, COUNT(Noise) AS Noisy FROM Ships;

SELECT round((length(atTime(Trip, getTime(Noise))) / 1000)::numeric, 1) AS Km,
  startTimestamp(Noise), endTimestamp(Noise)
FROM Ships WHERE MMSI = 220323000;

-------------------------------------------------------------------------------
-- The periods during which the noise of the fishing vessel reaches the
-- protected area 14, and the smallest distance between the trajectories of the
-- fishing vessel and of the passenger vessel
-------------------------------------------------------------------------------

SELECT whenTrue(tIntersects(v.Noise, n.Geom)) AS NoisePeriods
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 220323000 AND n.Id = 14;

SELECT round(nearestApproachDistance(a.Trip, b.Trip)::numeric, 2) AS TripDist
FROM Ships a, Ships b
WHERE a.MMSI = 220323000 AND b.MMSI = 219000407;

-------------------------------------------------------------------------------
-- How many vessels the noise of reaches how many protected areas that their
-- trajectories do not enter, over every realm
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS ExposureAll;
CREATE TABLE ExposureAll AS
SELECT v.MMSI, n.Id AS AreaId
FROM Ships v, NaturalAreas n
WHERE stbox(n.Geom) && stbox(v.Noise) AND eIntersects(n.Geom, v.Noise)
  AND NOT eIntersects(n.Geom, v.Trip);

SELECT COUNT(DISTINCT MMSI) AS Vessels, COUNT(DISTINCT AreaId) AS Areas
FROM ExposureAll;

-------------------------------------------------------------------------------
-- The vessels whose noise reaches a marine or coastal protected area, the areas
-- it reaches among all the marine and coastal ones, and, over these areas, the
-- vessels whose noise reaches an area their trajectories do not enter
-------------------------------------------------------------------------------

SELECT COUNT(DISTINCT MMSI) AS VesselsHeard,
  COUNT(DISTINCT AreaId) AS AreasReached
FROM Exposure;
SELECT COUNT(*) AS MarineCoastalAreas FROM NaturalAreas WHERE Realm <> 'Terrestrial';

SELECT COUNT(DISTINCT e.MMSI) AS Vessels, COUNT(DISTINCT e.AreaId) AS Areas
FROM Exposure e JOIN Ships v USING (MMSI)
  JOIN NaturalAreas n ON n.Id = e.AreaId
WHERE NOT eIntersects(v.Trip, n.Geom);

-------------------------------------------------------------------------------
-- How long the protected areas are quiet, free of any vessel noise, during the
-- day: the areas quiet for less than 3 minutes, for less than an hour, and for
-- more than 23 hours, and the longest quiet time
-------------------------------------------------------------------------------

WITH Heard AS (
  SELECT AreaId, spansetUnion(Heard) AS Heard
  FROM Exposure GROUP BY AreaId ),
Q AS (
  SELECT AreaId, 1440 - extract(epoch FROM duration(Heard)) / 60 AS MinutesQuiet
  FROM Heard )
SELECT COUNT(*) AS Areas,
  COUNT(*) FILTER (WHERE MinutesQuiet < 3) AS Below3,
  COUNT(*) FILTER (WHERE MinutesQuiet < 60) AS Below60,
  COUNT(*) FILTER (WHERE MinutesQuiet > 23 * 60) AS Above23h,
  round(MAX(MinutesQuiet)::numeric, 1) AS MaxMinutesQuiet
FROM Q;

-------------------------------------------------------------------------------
-- The pairs of vessels whose noise regions overlap, and those whose
-- trajectories never come closer than 5 kilometers
-------------------------------------------------------------------------------

SELECT COUNT(*) AS Pairs, COUNT(*) FILTER (WHERE TripDist > 5000) AS Far
FROM Encounter;

-------------------------------------------------------------------------------
-- The encounters at sea, whose trajectories never come closer than 5
-- kilometers: how many pairs, and the median length of an encounter
-------------------------------------------------------------------------------

SELECT COUNT(*) AS Pairs,
  round(percentile_cont(0.5) WITHIN GROUP
    (ORDER BY extract(epoch FROM duration(Overlap)) / 60)::numeric, 1) AS MedianMinutes
FROM Encounter
WHERE TripDist > 5000;
