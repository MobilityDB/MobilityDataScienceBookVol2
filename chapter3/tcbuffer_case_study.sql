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
