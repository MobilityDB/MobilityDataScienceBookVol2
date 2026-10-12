-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
-- Case study: underwater noise. The queries of the chapter, in its order, on the
-- database built by tcbuffer_load.sql for one day of AIS data of the Danish
-- Maritime Authority. The comment under each query is the answer it gives.
\pset footer off
SET TimeZone = 'UTC';

-- The area affected by the noise of the fishing vessel during its trip
SELECT round((ST_Area(traversedArea(Noise, true)) / 1e6)::numeric, 2) AS AreaKm2
FROM VesselTrip
WHERE MMSI = 219013538 AND TripId = 1;
-- 204.18

-- Evaluating the quietness of protected areas
SELECT aDwithin(n.Geom, v.Noise, 1000)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 219013538 AND v.TripId = 1 AND n.Id = 22;
-- f

SELECT eIntersects(n.Geom, v.Noise), eContains(n.Geom, v.Noise)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 219013538 AND v.TripId = 1 AND n.Id = 22;
-- t | f

SELECT eIntersects(n.Geom, v.Trip),
  duration(whenTrue(tIntersects(v.Noise, n.Geom))) AS NoiseInArea,
  duration(whenTrue(tDwithin(v.Noise, n.Geom, 1000))) AS Within1km
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 219013538 AND v.TripId = 1 AND n.Id = 22;
-- f | 00:29:01.135545 | 00:45:49.106695

SELECT aIntersects(n.Geom, v.Noise)
FROM VesselTrip v, NaturalAreas n
WHERE v.MMSI = 219013538 AND v.TripId = 1 AND n.Id = 22;
-- f

-- Monitoring the distance between the moving regions of two vessels
CREATE OR REPLACE VIEW Fishing(Noise) AS
  SELECT Noise FROM VesselTrip WHERE MMSI = 219013538 AND TripId = 1;
CREATE OR REPLACE VIEW Passenger(Noise) AS
  SELECT Noise FROM VesselTrip WHERE MMSI = 219000407 AND TripId = 1;

SELECT numInstants(tDistance(a.Noise, b.Noise)),
  round(minValue(tDistance(a.Noise, b.Noise))::numeric, 2),
  round(maxValue(tDistance(a.Noise, b.Noise))::numeric, 2)
FROM Fishing a, Passenger b;
-- 14821 | 5638.93 | 37499.60

SELECT asText(nearestApproachInstant(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- Cbuffer(POINT(628150.42 6355145.18),162.4)@2025-01-01 08:57:51+00

SELECT round(nearestApproachDistance(a.Noise, b.Noise)::numeric, 2)
FROM Fishing a, Passenger b;
-- 5638.93

SELECT ST_AsText(shortestLine(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- LINESTRING(627988.08 6355140.95,622351.06 6354994.1)

-- The exposure of the protected areas over the day
CREATE TABLE Exposure AS
SELECT v.MMSI, v.TripId, n.Id AS AreaId,
  whenTrue(tIntersects(n.Geom, v.Noise)) AS Heard
FROM VesselTrip v, NaturalAreas n
WHERE n.Realm <> 'Terrestrial' AND stbox(n.Geom) && stbox(v.Noise)
  AND eIntersects(n.Geom, v.Noise);
-- SELECT 2647

SELECT n.NameEng, count(DISTINCT e.MMSI) AS Vessels,
  round((sum(extract(epoch FROM duration(e.Heard))) / 3600)::numeric, 1)
    AS VesselHours
FROM Exposure e JOIN NaturalAreas n ON n.Id = e.AreaId
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC LIMIT 3;
-- W|134|1861.0
-- Skagens Gren og Skagerrak|126|384.2
-- Nordvestlige Kattegat|88|295.6

SELECT maxValue(tCount(Heard)) AS MaxVessels,
  startTimestamp(atMax(tCount(Heard))) AS AtTime
FROM Exposure WHERE AreaId = 122;
-- 85|2025-01-01 02:53:15.584947+00

WITH Heard AS (
  SELECT AreaId, spansetUnion(Heard) AS Heard
  FROM Exposure GROUP BY AreaId )
SELECT n.NameEng, round((1440 - extract(epoch FROM duration(h.Heard))
  / 60)::numeric, 1) AS MinutesQuiet
FROM Heard h JOIN NaturalAreas n ON n.Id = h.AreaId
ORDER BY MinutesQuiet, n.NameEng LIMIT 3;
-- Nordvestlige Kattegat|0.0
-- Smålandsfarvandet|0.0
-- W|0.0

SELECT n.NameEng, count(DISTINCT e.MMSI) AS Vessels
FROM Exposure e JOIN VesselTrip v USING (MMSI, TripId)
  JOIN NaturalAreas n ON n.Id = e.AreaId
WHERE NOT eIntersects(v.Trip, n.Geom)
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC LIMIT 3;
-- Herthas Flak|71
-- Nordvestlige Kattegat|62
-- Langeland Kommune public|61

-- Acoustic encounters
CREATE TABLE Encounter AS
SELECT a.MMSI AS MMSI1, a.TripId AS TripId1,
  b.MMSI AS MMSI2, b.TripId AS TripId2,
  whenTrue(tIntersects(a.Noise, b.Noise)) AS Overlap,
  nearestApproachDistance(a.Trip, b.Trip) AS TripDist
FROM VesselTrip a, VesselTrip b
WHERE a.MMSI < b.MMSI AND stbox(a.Noise) && stbox(b.Noise)
  AND eIntersects(a.Noise, b.Noise);
-- SELECT 21678

CREATE TABLE SeaEncounter AS
SELECT * FROM (
  SELECT e.MMSI1, e.MMSI2, e.TripDist, e.Overlap *
    whenTrue((a.Speed #> 2.0) & (b.Speed #> 2.0)) AS Overlap
  FROM Encounter e
    JOIN VesselTrip a ON (a.MMSI, a.TripId) = (e.MMSI1, e.TripId1)
    JOIN VesselTrip b ON (b.MMSI, b.TripId) = (e.MMSI2, e.TripId2)
  WHERE e.TripDist > 5000 ) AS t
WHERE Overlap IS NOT NULL;
-- SELECT 4326

SELECT MMSI1, MMSI2, duration(Overlap) AS Overlap
FROM SeaEncounter ORDER BY duration(Overlap) DESC LIMIT 1;
-- 352002271|636018854|18:19:53.85443
