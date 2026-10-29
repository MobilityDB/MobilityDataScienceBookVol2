-- Query 1. Trips that crosses the largest number of districts.
WITH tripInt AS
 (SELECT vehicleid, tripid,
         COUNT(DISTINCT m.municipalityid) AS intersectCount
  FROM trips t, municipalities m
  WHERE eintersects(trip, municipalitygeo)
GROUP BY vehicleid, tripid)
SELECT t1.*, ST_AsText(t.trajectory) AS trajectory
FROM trips t JOIN tripInt t1 ON (t.tripId = t1.tripId AND t.vehicleid = t1.vehicleid)
ORDER BY intersectCount DESC
LIMIT 1;

-- Query 2. Total distance traveled per minicipality.
SELECT m.MunicipalityName,
  round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 3)
    AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo)
GROUP BY m.MunicipalityName;
