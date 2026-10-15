-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: In-Memory, Large-Scale and Stream Processing
-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
--
-- The numbers the text of the underwater-noise case study quotes and no
-- listing prints
--
-- Reads the database built by tcbuffer_load_ais.sh and the tables Exposure,
-- Encounter and SeaEncounter built by tcbuffer_case_study.sql. Run after that
-- script:
--   psql -d noise -f text_numbers.sql
-------------------------------------------------------------------------------

\timing on
SET TimeZone = 'UTC';

-------------------------------------------------------------------------------
-- The trips of the day, and the length and the period of the trip of the
-- fishing vessel
-------------------------------------------------------------------------------

SELECT count(*) AS Trips FROM VesselTrip;

SELECT round((length(Trip) / 1000)::numeric, 1) AS Km, startTimestamp(Trip),
  endTimestamp(Trip)
FROM VesselTrip WHERE MMSI = 220323000 AND TripId = 1;

-------------------------------------------------------------------------------
-- The periods during which the noise of the fishing vessel reaches the
-- protected area 14, and the smallest distance between the trajectories of the
-- fishing vessel and of the passenger vessel
-------------------------------------------------------------------------------

SELECT whenTrue(tIntersects(v.Noise, n.Geom)) AS NoisePeriods
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 220323000 AND v.TripId = 1 AND n.Id = 14;

SELECT round(nearestApproachDistance(a.Trip, b.Trip)::numeric, 2) AS TripDist
FROM VesselTrip a, VesselTrip b
WHERE (a.MMSI, a.TripId) = (220323000, 1) AND (b.MMSI, b.TripId) = (219000407, 1);

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
-- The trips whose noise reaches a marine or coastal protected area, the areas
-- it reaches among all the marine and coastal ones, and, over these areas, the
-- trips whose noise reaches an area their trajectories do not enter
-------------------------------------------------------------------------------

SELECT count(DISTINCT (MMSI, TripId)) AS TripsHeard,
  count(DISTINCT AreaId) AS AreasReached
FROM Exposure;
SELECT count(*) AS MarineCoastalAreas FROM NaturalAreas WHERE Realm <> 'Terrestrial';

SELECT count(DISTINCT (e.MMSI, e.TripId)) AS Trips, count(DISTINCT e.AreaId) AS Areas
FROM Exposure e JOIN VesselTrip v USING (MMSI, TripId)
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
SELECT count(*) AS Areas,
  count(*) FILTER (WHERE MinutesQuiet < 3) AS Below3,
  count(*) FILTER (WHERE MinutesQuiet < 60) AS Below60,
  count(*) FILTER (WHERE MinutesQuiet > 23 * 60) AS Above23h,
  round(max(MinutesQuiet)::numeric, 1) AS MaxMinutesQuiet
FROM Q;

-------------------------------------------------------------------------------
-- The pairs of trips whose noise regions overlap, and those whose trajectories
-- never come closer than 5 kilometers
-------------------------------------------------------------------------------

SELECT count(*) AS Pairs, count(*) FILTER (WHERE TripDist > 5000) AS Far
FROM Encounter;

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
