WITH Timestamps AS (
  SELECT DISTINCT  v.Licence, p.pointId, p.Geom,
    MIN(startTimestamp(atValue(t.Trip, p.Geom))) AS Instant
  FROM Trips t, Vehicles v, Points p
  WHERE t.VehicleId = v.VehicleId AND
    v.VehicleType = 'passenger' AND eIntersects(t.Trip, p.Geom)
  GROUP BY v.Licence, p.pointId, p.Geom )
SELECT t1.*
FROM Timestamps t1
WHERE t1.Instant <= ALL (
  SELECT t2.Instant
  FROM Timestamps t2
  WHERE t1.PointId = t2.PointId )
ORDER BY t1.PointId, t1.Licence;
