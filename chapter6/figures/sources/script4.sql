SELECT TripId, kind, fromTime, toTime, Geom
FROM Tours
WHERE kind @? '$ ? (
      @."CategoryName" == "Restaurant" &&
      @."TypeOfFood"   == "French" &&
      @."Price"        == "Moderate"
)';

WITH Ordered AS (
  SELECT
    TripId,
    kind,
    fromTime,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY fromTime) AS rn
  FROM Tours
)
SELECT 
    a.TripId,
    a.kind AS first_stop,
    b.kind AS second_stop,
    a.fromTime AS first_time,
    b.fromTime AS second_time
FROM Ordered a
JOIN Ordered b
  ON a.TripId = b.TripId
 AND b.rn = a.rn + 1
WHERE
  a.kind @? '$ ? ( @."Price" == "Moderate" )'
  AND
  b.kind @? '$ ? ( @."Price" == "Moderate" )'
ORDER BY a.TripId;

-- %%%%%%%%%%%%%%%%%%%%%
select st_buffer(geom::geometry, 1) from poi where poiid=3

SELECT ST_Buffer(Geom::geography, 500)::geometry AS buffer_geom
FROM Poi
WHERE Name = 'Centre Pompidou';
select * from tours
alter table poi add column Type text
update poi set
type = 'Amenity' where poiid=7 or poiid=1
SELECT TripId,
       ST_MakeLine(Geom ORDER BY fromTime) AS trajectory_geom
FROM Tours
GROUP BY TripId
ORDER BY TripId;