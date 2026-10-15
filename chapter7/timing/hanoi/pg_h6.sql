WITH TripPeriod AS(
  SELECT tripid, pId, p.SpanP, vehicleid, atTime(T.Trip, P.SpanP) as tripPeriod
  FROM Trips T, Bins P
  WHERE T.Trip && P.SpanP)
SELECT T.Pid as intervalId, T.SpanP as intervalTime, M.municipalityName as
  Municipality, COUNT(*) as tripsCount
FROM TripPeriod T, Municipalities M
WHERE eintersects(TripPeriod, M.MunicipalityGeo)
GROUP BY T.Pid,T.SpanP,  M.municipalityName
ORDER BY COUNT(*) desc, M.municipalityName,T.Pid;
