SELECT DISTINCT t1.VehicleId AS VehicleId1, t1.TripId AS TripId1,
  ST_AsText(t1.Trajectory) AS Traj1, t2.VehicleId AS VehicleId2, t2.TripId AS TripId2,
  ST_AsText(t2.Trajectory) AS Traj2
FROM (SELECT * FROM trips t1 LIMIT 1000) t1,
  (SELECT * FROM trips t2 LIMIT 1000) t2
WHERE t1.VehicleId < t2.VehicleId AND eDwithin(t1.Trip, t2.Trip, 10.0)
ORDER BY t1.VehicleId, t2.VehicleId;
