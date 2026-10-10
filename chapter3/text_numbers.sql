-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: In-Memory, Large-Scale and Stream Processing
-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
--
-- The numbers the text of the underwater-noise case study quotes and no
-- listing prints
--
-- Reads the database built by tcbuffer_load.sql and the tables Exposure and
-- SeaEncounter built by tcbuffer_case_study.sql. Run after that script:
--   psql -d noise -f text_numbers.sql
--
-- Last run against PostgreSQL 18.6, PostGIS 3.6.4, MobilityDB 1.4.
-------------------------------------------------------------------------------

\timing on
SET TimeZone = 'UTC';

-------------------------------------------------------------------------------
-- How many trips the noise of reaches how many protected areas that their
-- trajectories do not enter, over every realm
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS ExposureAll;
CREATE TABLE ExposureAll AS
SELECT v.MMSI, v.TripId, n.Id AS AreaId
FROM VesselTrip v, NaturalAreas n
WHERE stbox(n.Geom) && stbox(v.Noise) AND eIntersects(n.Geom, v.Noise)
  AND NOT eIntersects(n.Geom, v.Trip);

SELECT count(DISTINCT (MMSI, TripId)) AS Trips, count(DISTINCT AreaId) AS Areas
FROM ExposureAll;

-------------------------------------------------------------------------------
-- How long each of the most exposed areas is quiet, free of any vessel noise,
-- during the day
-------------------------------------------------------------------------------

WITH Heard AS (
  SELECT AreaId, spansetUnion(Heard) AS Heard FROM Exposure GROUP BY AreaId )
SELECT n.NameEng,
  round((extract(epoch FROM duration(h.Heard)) / 3600)::numeric, 1) AS HoursHeard,
  round((24 - extract(epoch FROM duration(h.Heard)) / 3600)::numeric, 1) AS HoursQuiet
FROM Heard h JOIN NaturalAreas n ON n.Id = h.AreaId
ORDER BY HoursHeard DESC LIMIT 5;

-------------------------------------------------------------------------------
-- The encounters at sea of two vessels under way: how many pairs, how many
-- vessels, the median length of an encounter and the farthest apart that two
-- encountering trips stay
-------------------------------------------------------------------------------

SELECT count(*) AS Pairs, count(DISTINCT MMSI1) + count(DISTINCT MMSI2) AS Vessels,
  round(percentile_cont(0.5) WITHIN GROUP
    (ORDER BY extract(epoch FROM duration(Overlap)) / 60)::numeric, 1) AS MedianMinutes,
  round(max(TripDist)) AS MaxTripDist
FROM SeaEncounter;
