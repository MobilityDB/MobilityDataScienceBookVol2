SELECT T1.tripid, T1.VehicleId AS VehId1, C2.VehicleId AS VehId2, C2.Distance
FROM Trips200 T1, LATERAL (
  SELECT T2.VehicleId, minValue(T1.Trip <-> T2.Trip) AS Distance
  FROM Trips200 T2
  WHERE T1.VehicleId < T2.VehicleId AND TimeSpan(T1.Trip) && TimeSpan(T2.Trip)
  ORDER BY Distance LIMIT 3 ) AS C2
ORDER BY T1.tripid, T1.VehicleId, C2.Distance, C2.VehicleId;
