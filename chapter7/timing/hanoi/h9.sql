WITH Groups AS (
 SELECT ((ROW_NUMBER() OVER (ORDER BY V.Vehicleid))-1)//10 + 1 AS GroupId,
  V.Vehicleid
 FROM Vehicles V ),
SumDistances AS (
 SELECT G.GroupId, P.PointId,
   SUM(ST_Distance(T.trajectory, P.Geom)) AS SumDist
 FROM Groups G, Points P, Trips T
 WHERE T.Vehicleid = G.Vehicleid
 GROUP BY G.GroupId, P.PointId )
SELECT S1.GroupId, S1.PointId, S1.SumDist
FROM SumDistances S1
WHERE S1.SumDist <= ALL (
  SELECT SumDist
  FROM SumDistances S2
  WHERE S1.GroupId = S2.GroupId )
ORDER BY S1.GroupId, S1.PointId;
