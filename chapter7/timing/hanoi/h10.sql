SELECT DISTINCT t.TripId, v.Licence, p.PointId, st_astext(p.Geom),
  startTimestamp(atValue(t.Trip, p.Geom))  AS Instant,
  ST_AsText(t.trajectory) as trajectory
FROM Trips t, Vehicles v, Points p
WHERE t.VehicleId = v.VehicleId AND v.VehicleType = 'passenger' AND
  eIntersects(t.Trip, ST_Buffer(p.Geom,10));
