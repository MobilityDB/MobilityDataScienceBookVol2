WITH TripsTraj AS(
  SELECT TripId, VehicleId, Trajectory
  FROM Trips ),
PointTrips AS(
  SELECT P.PointId, T2.VehicleId, T2.TripId, T2.Distance
  FROM Points P, LATERAL (
    SELECT T1.VehicleId, T1.TripId,
      ST_Distance(P.geom, T1.Trajectory) AS Distance
    FROM TripsTraj T1
    ORDER BY Distance LIMIT 3 ) AS T2 )
SELECT T.TripId, T.VehicleId, P.PointId, PT.Distance
FROM Trips T  JOIN PointTrips PT ON
    (T.VehicleId = PT.VehicleId  AND T.TripId = PT.TripId)
       JOIN Points P ON P.PointId = PT.PointId
ORDER BY T.VehicleId, T.TripId, P.PointId;
