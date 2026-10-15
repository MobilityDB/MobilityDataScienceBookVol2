-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
-- Case study: underwater noise. The queries of the chapter, in its order, on the
-- database built by tcbuffer_load_ais.sh for January 20, 2026, from the AIS
-- database of the book. The comment under each query is the answer it gives.
\pset footer off
SET TimeZone = 'UTC';

-- The area affected by the noise of the fishing vessel during its trip
SELECT round((ST_Area(traversedArea(Noise, true)) / 1e6)::numeric, 2) AS AreaKm2
FROM VesselTrip
WHERE MMSI = 220323000 AND TripId = 1;
-- 182.75

-- Evaluating the quietness of protected areas
SELECT aDwithin(n.Geom, v.Noise, 1000)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 220323000 AND v.TripId = 1 AND n.Id = 14;
-- f

SELECT eIntersects(n.Geom, v.Noise), eContains(n.Geom, v.Noise)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 220323000 AND v.TripId = 1 AND n.Id = 14;
-- t | f

SELECT eIntersects(n.Geom, v.Trip),
  duration(whenTrue(tIntersects(v.Noise, n.Geom))) AS NoiseInArea,
  duration(whenTrue(tDwithin(v.Noise, n.Geom, 1000))) AS Within1km
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 220323000 AND v.TripId = 1 AND n.Id = 14;
-- f | 00:27:53.927402 | 00:36:48.886162

SELECT aIntersects(n.Geom, v.Noise)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 220323000 AND v.TripId = 1 AND n.Id = 14;
-- f

-- The exposure of the protected areas over the day
CREATE TABLE Exposure AS
SELECT v.MMSI, v.TripId, n.Id AS AreaId,
  whenTrue(tIntersects(n.Geom, v.Noise)) AS Heard
FROM VesselTrip v, NaturalAreas n
WHERE n.Realm <> 'Terrestrial' AND stbox(n.Geom) && stbox(v.Noise)
  AND eIntersects(n.Geom, v.Noise);
-- SELECT 4130

SELECT n.NameEng, count(DISTINCT e.MMSI) AS Vessels,
  round((sum(extract(epoch FROM duration(e.Heard))) / 3600)::numeric, 1)
    AS VesselHours
FROM Exposure e JOIN NaturalAreas n ON n.Id = e.AreaId
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC LIMIT 3;
-- Skagens Gren og Skagerrak | 184 | 756.6
-- I | 145 | 258.3
-- W | 131 | 842.7

SELECT maxValue(tCount(Heard)) AS MaxVessels,
  startTimestamp(atMax(tCount(Heard))) AS AtTime
FROM Exposure WHERE AreaId = 122;
-- 43 | 2026-01-20 00:02:43.577183+00

WITH Heard AS (
  SELECT AreaId, spansetUnion(Heard) AS Heard
  FROM Exposure GROUP BY AreaId )
SELECT n.NameEng, round((1440 - extract(epoch FROM duration(h.Heard))
  / 60)::numeric, 1) AS MinutesQuiet
FROM Heard h JOIN NaturalAreas n ON n.Id = h.AreaId
ORDER BY MinutesQuiet, n.NameEng LIMIT 3;
-- C | 0.0
-- Nordvestlige Kattegat | 0.0
-- Schultz og Hastens Grund samt Briseis Flak | 0.0

SELECT n.NameEng, count(DISTINCT e.MMSI) AS Vessels
FROM Exposure e JOIN VesselTrip v USING (MMSI, TripId)
  JOIN NaturalAreas n ON n.Id = e.AreaId
WHERE NOT eIntersects(v.Trip, n.Geom)
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC, n.NameEng LIMIT 3;
-- Saltholm og omliggende hav | 92
-- Saltholm og omliggende hav | 92
-- Q | 90

-- Monitoring the distance between the moving regions of two vessels
CREATE OR REPLACE VIEW Fishing(Noise) AS
  SELECT Noise FROM VesselTrip WHERE MMSI = 220323000 AND TripId = 1;
CREATE OR REPLACE VIEW Passenger(Noise) AS
  SELECT Noise FROM VesselTrip WHERE MMSI = 219000407 AND TripId = 1;

SELECT numInstants(tDistance(a.Noise, b.Noise)),
  round(minValue(tDistance(a.Noise, b.Noise))::numeric, 2),
  round(maxValue(tDistance(a.Noise, b.Noise))::numeric, 2)
FROM Fishing a, Passenger b;
-- 13600 | 6244.47 | 63220.24

SELECT asText(nearestApproachInstant(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- Cbuffer(POINT(628134.55 6355170.76),108.26)@2026-01-20 17:56:13+00

SELECT round(nearestApproachDistance(a.Noise, b.Noise)::numeric, 2)
FROM Fishing a, Passenger b;
-- 6244.47

SELECT ST_AsText(shortestLine(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- LINESTRING(628026.29 6355170.03,621781.96 6355128)

-- Acoustic encounters
CREATE TABLE Encounter AS
SELECT a.MMSI AS MMSI1, a.TripId AS TripId1,
  b.MMSI AS MMSI2, b.TripId AS TripId2,
  whenTrue(tIntersects(a.Noise, b.Noise)) AS Overlap,
  nearestApproachDistance(a.Trip, b.Trip) AS TripDist
FROM VesselTrip a, VesselTrip b
WHERE a.MMSI < b.MMSI AND stbox(a.Noise) && stbox(b.Noise)
  AND eIntersects(a.Noise, b.Noise);
-- SELECT 48376

CREATE TABLE SeaEncounter AS
SELECT * FROM (
  SELECT e.MMSI1, e.MMSI2, e.TripDist, e.Overlap *
    whenTrue((a.Speed #> 2.0) & (b.Speed #> 2.0)) AS Overlap
  FROM Encounter e
    JOIN VesselTrip a ON (a.MMSI, a.TripId) = (e.MMSI1, e.TripId1)
    JOIN VesselTrip b ON (b.MMSI, b.TripId) = (e.MMSI2, e.TripId2)
  WHERE e.TripDist > 5000 ) AS t
WHERE Overlap IS NOT NULL;
-- SELECT 15314

SELECT MMSI1, MMSI2, duration(Overlap) AS Overlap
FROM SeaEncounter ORDER BY duration(Overlap) DESC LIMIT 1;
-- 273277840 | 319114200 | 20:45:27.579949
