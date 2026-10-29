SELECT tripId, atValues(trip, text '[Street, Quai Voltaire]') as traj
FROM  Tripsparis1
WHERE atValues(trip, text '[Street, Quai Voltaire]') is not null

SELECT tripId, (atValues(trip, text '[Street, Av. des Champs-Elyses]'))::tstzspan
FROM  TripsParis1
WHERE atValues(trip, text '[Street, Av. des Champs-Elyses]') is not null 

select * from tripsParis1
CREATE TABLE tripsParis1 (tripid int, trip ttext);

INSERT INTO tripsParis1 VALUES
  (1, ttext '["[Street, Bvd. St Germain]"@2025-06-13 19:00:00,
  "[Street, Quai Voltaire]"@2025-06-13 19:10:00, 
  "[Street, Quai d''Orsai]"@2025-06-13 19:20:00,
  "[Street, Av. de Maringny]"@2025-06-13 19:25:00,
  "[Street, Rue du Faubourg Saint-Honore]"@2025-06-13 22:00:00]'),
  (2, ttext '["[Street, Av. des Champs-Elyses]"@2025-06-13 15:00:00,  
  "[Street, Av. George V"@2025-06-13 16:00:00], "[Street, Course La Reine]"@2025-06-13 16:20:00]');
  
SELECT * FROM tripsParis
INSERT INTO tripsParis1 VALUES
  (3, ttext '["[Street, Bvd. St Germain]"@2025-06-13 18:30:00,
  "[Street, Bvd. St Michel]"@2025-06-13 21:10:00 ]')
   
   
SELECT  
    t1.tripid AS trip1,
    t2.tripid AS trip2,
    WhenTrue(t1.trip #= t2.trip) as timecoincide
    FROM tripsparis t1 JOIN tripsparis t2 ON t1.tripid < t2.tripid
WHERE WhenTrue(t1.trip #= t2.trip) IS NOT NULL


WITH Overlap AS (
	SELECT
    t1.tripid AS trip1,
    t2.tripid AS trip2,
    WhenTrue(t1.trip #= t2.trip) as timecoincide
    FROM tripsparis t1 JOIN tripsparis t2 ON t1.tripid < t2.tripid),
OverlapInstants AS(
    SELECT distinct trip1, trip2, (atTime(trip, timecoincide)) as sameRoute
    FROM overlap, tripsparis)
SELECT trip1, trip2, getValue(unnest(instants(sameRoute))) as Road,
getTimestamp(unnest(instants(sameRoute))) Time
FROM OverlapInstants
ORDER BY Road

(1, ttext '["[Street, Bvd. St Germain]"@2025-06-13 19:00:00,
  "[Street, Quai Voltaire]"@2025-06-13 19:10:00, 
  "[Street, Quai d''Orsai]"@2025-06-13 19:20:00,
  "[Street, Av. de Maringny]"@2025-06-13 19:25:00,
  "[Street, Rue du Faubourg Saint-Honore]"@2025-06-13 22:00:00]'),
  
INSERT INTO tripsParis1 VALUES
(2, ttext '["[Street, Av. des Champs-Elyses]"@2025-06-13 15:00:00,  
  "[Street, Av. George V]"@2025-06-13 16:00:00, 
  "[Street, Course La Reine]"@2025-06-13 16:20:00]');
  
SELECT tripId, valueattimestamp(trip, '2025-06-13 20:05:00')
FROM  TripsParis1
WHERE valueattimestamp(trip, '2025-06-13 20:05:00') is not null
  
SELECT  
    t1.tripid AS trip1,
    t2.tripid AS trip2,
    WhenTrue(t1.trip #= t2.trip) as timecoincide
    FROM tripsparis1 t1 JOIN tripsparis1 t2 ON t1.tripid < t2.tripid
WHERE WhenTrue(t1.trip #= t2.trip) IS NOT NULL