SELECT m.MunicipalityName,
  round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)
    ::numeric, 3) AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo)
GROUP BY m.MunicipalityName;
