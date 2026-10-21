-- The Hanoi numbers that chapter 7 prints, recomputed in MobilityDB over the loaded data.
\timing off
SELECT municipalityname, COUNT(*) AS intersectCount
FROM trips t, municipalities m
WHERE eintersects(t.trip, m.municipalitygeo)
GROUP BY municipalityname
ORDER BY intersectCount DESC LIMIT 6;
SELECT round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 0) AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo);
WITH k AS (
  SELECT m.MunicipalityName, round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 0) AS km
  FROM Trips t, Municipalities m
  WHERE eintersects(t.trip, m.MunicipalityGeo)
  GROUP BY m.MunicipalityName)
(SELECT * FROM k ORDER BY km LIMIT 1) UNION ALL (SELECT * FROM k ORDER BY km DESC LIMIT 1);
SELECT COUNT(*) AS pairs FROM (
SELECT DISTINCT t1.VehicleId, t1.TripId, t2.VehicleId, t2.TripId
FROM (SELECT * FROM trips t1 ORDER BY TripId LIMIT 1000) t1,
  (SELECT * FROM trips t2 ORDER BY TripId LIMIT 1000) t2
WHERE t1.VehicleId < t2.VehicleId AND eDwithin(t1.Trip, t2.Trip, 10.0)) x;
