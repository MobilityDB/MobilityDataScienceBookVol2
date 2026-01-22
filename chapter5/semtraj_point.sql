
SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';
  
DROP TABLE IF EXISTS TripPoints;
CREATE TABLE TripPoints(TripId integer, DeviceId text, T timestamptz, Uid text,
  Pm25 float, Geom geometry, Attributes jsonb, PRIMARY KEY(DeviceId, TripId, T));
INSERT INTO TripPoints
WITH DelhiStart AS (
  SELECT *,
    CASE WHEN LAG(T) OVER w IS NULL OR T - LAG(T) OVER w > '5 minutes' OR
      ST_Distance(Geom, LAG(Geom) OVER w) > 1000 THEN 1
    END AS StartInst
  FROM DelhiInput
  WINDOW w AS (PARTITION BY DeviceId ORDER BY T) ),
DelhiGroup AS (
  SELECT *, COUNT(StartInst) OVER (ORDER BY DeviceId, T) AS TripId
  FROM DelhiStart )
SELECT g.TripId, g.DeviceId, g.T, g.Uid, g.Pm2_5, g.Geom, s.Attributes
FROM DelhiGroup g, DelhiInputSem s
WHERE g.DeviceId = s.DeviceId AND g.T = s.T
ORDER BY TripId;

-- INSERT 0 7087619
-- Time: 145731.315 ms (02:25.731)

CREATE INDEX TripPoints_Geom_Idx ON TripPoints USING SPGIST(Geom);

-- Time: 60202.869 ms (01:00.203)

------------------------------------------------------------------------------

-- Query 5.29. Trips where the Pm25 increases throughout the entire trip

-- DROP TABLE IF EXISTS Q5_29;
-- CREATE TABLE Q5_29 AS
WITH TripPm25(TripId, T, Pm25, NextPm25) AS (
  SELECT TripId, T, Pm25, LEAD(Pm25) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPoints ),
TripsIncPm25(TripId) AS (
  SELECT TripId
  FROM TripPm25
  WHERE NextPm25 IS NOT NULL
  GROUP BY TripId
  HAVING bool_and(Pm25 < NextPm25) )
SELECT p.TripId, MIN(p.T) AS StartTime, MAX(p.T) AS EndTime,
  array_agg(p.Pm25 ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, TripsIncPm25 i
WHERE p.TripId = i.TripId
GROUP BY p.TripId
ORDER BY TripId, StartTime;

-- SELECT 708
-- Time: 70 secs 
-- EZ
-- (708 rows)
-- Time: 11001.128 ms (00:11.001)

-- TEMPORAL VERSION

-- DROP TABLE IF EXISTS TQ5_29;
-- CREATE TABLE TQ5_29 AS
WITH Segments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips
  WHERE numInstants(Pm2_5) > 1 )
SELECT TripId, DeviceId, Pm2_5
FROM DelhiTrips
WHERE numInstants(Pm2_5) > 1 AND tripId NOT IN (
  SELECT DISTINCT TripId
  FROM Segments
  WHERE startValue(Segm) >= endValue(Segm) );

-- (708 rows)
-- Time: 3166.353 ms (00:03.166)

------------------------------------------------------------------------------

/*
Query 5.30. Trips have at least a continuous run of 1.5 minutes
with strictly increasing Pm25, followed by a continuous run of
strictly decreasing Pm25, also with a 1.5 minutes duration.


[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '10 minutes' ]+.*
[ (Pm25, @q), prev(Pm25) > @q ]{3-5}
I+.D+
*/
DROP TABLE IF EXISTS Q5_30;
CREATE TABLE Q5_30 AS 
WITH TripPm25 (TripId, T, Pm25, Trend) AS (
  SELECT TripId, T, Pm25,
   CASE
    WHEN Pm25 > LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) THEN  1 
    WHEN Pm25 < LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) THEN -1
   	ELSE 0
 	END
  FROM TripPoints),
Runs (TripId, T, Pm25, Trend, PrevT, PrevPm25, PrevTrend) AS (
  SELECT TripId, T, Pm25, Trend,
   LAG(T) OVER (PARTITION BY TripId ORDER BY T),
   LAG(Pm25)  OVER (PARTITION BY TripId ORDER BY T),
   LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25
  -- WHERE Trend <> 0
),
RunIds (TripId, RunId, T, Pm25, Trend, PrevT, PrevPm25) AS (
  SELECT TripId, SUM(
   CASE 
    WHEN Trend = PrevTrend THEN 0 ELSE 1 END) OVER (PARTITION BY TripId 
     ORDER BY T), T, Pm25, Trend, PrevT, PrevPm25
  FROM Runs)--,
--RunTimes (TripId, RunId, Trend, StartTime, EndTime,  FirstT, LastT, Duration) AS (
  SELECT TripId, RunId, Trend, MIN(PrevT), MAX(T), MIN(T), MAX(T),
   EXTRACT(EPOCH FROM MAX(T) - MIN(PrevT)) / 60.0
  FROM RunIds
  GROUP BY TripId, RunId, Trend
  HAVING EXTRACT(EPOCH FROM MAX(T) - MIN(PrevT)) / 60.0 >= 1.5
),
RunBounds (TripId, RunId, Trend, StartTime, EndTime, Duration, StartPm25,
 EndPm25) AS (
  SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime, r.Duration, sp.PrevPm25,
   ep.Pm25
  FROM RunTimes r, RunIds sp, RunIds ep
  WHERE sp.TripId = r.TripId AND sp.T = r.FirstT AND ep.TripId = r.TripId 
   AND ep.T = r.LastT),
SelectedRuns (TripId, IncRun, DecRun) AS (
  SELECT
    r1.TripId,
    r1.RunId AS IncRun,
    r2.RunId AS DecRun
  FROM RunTimes r1, RunTimes r2
  WHERE r2.TripId = r1.TripId
    AND r1.Trend  =  1
    AND r2.Trend  = -1
    AND r2.StartTime = r1.EndTime
)

SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime, r.Duration, r.StartPm25, 
 r.EndPm25
FROM RunBounds r, SelectedRuns s
WHERE s.TripId = r.TripId AND r.RunId IN (s.IncRun, s.DecRun)
ORDER BY r.TripId, r.RunId; 

-- 65 trips (138 tules)
-- 3 min 30secs

 

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_30;
CREATE TABLE TQ5_30 AS
WITH TripSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips
  WHERE TripId = 5217
  ),
TripSegmTrend(TripId, Trend, T) AS (
  SELECT TripId,
    CASE
      WHEN startValue(Segm) < endValue(Segm) THEN 'I'
      WHEN startValue(Segm) > endValue(Segm) THEN 'D'
      ELSE 'C'
    END, startTimestamp(Segm)
  FROM TripSegments ),
TripTrend(TripId, Trend) AS (
  SELECT TripId, ttextSeq(array_agg(ttext(Trend, T) ORDER BY T))
  FROM TripSegmTrend
  WHERE Trend <> 'C'
  GROUP BY TripId ),
TrendSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Trend))
  FROM TripTrend ),
TripLabel(TripId, Label) AS (
  SELECT TripId, string_agg(
    CASE
      WHEN startValue(Segm) = 'I' AND duration(Segm) > '1.5 min' THEN 'A'
      WHEN startValue(Segm) = 'D' AND duration(Segm) > '1.5 min' THEN 'B'
      ELSE '.'
    END, '' ORDER BY Segm)
  FROM TrendSegments 
  GROUP BY TripId ),
TripMatches(TripId, Pm2_5, StartInst, EndInst) AS (
  SELECT l.TripId, Pm2_5, instantN(Pm2_5, regexp_instr(Label, 'AB')),
    instantN(Pm2_5, regexp_instr(Label, 'AB') + 
      length(substring(Label FROM 'AB')) - 1)
  FROM TripLabel l, DelhiTrips t
  WHERE l.TripId = t.TripId AND Label ~ 'AB' )
SELECT TripId, atTime(Pm2_5, span(getTimestamp(StartInst), 
  getTimestamp(EndInst)))
FROM TripMatches
ORDER BY Tripid;

-- SELECT 94
-- Time: 21647.805 ms (00:21.648)

/*
WITH Temp AS (
  SELECT DISTINCT TripId FROM tq5_30
  EXCEPT
  SELECT DISTINCT TripId FROM q5_30 ORDER BY TripId)
SELECT array_agg(TripId ORDER BY TripId) from Temp;

 {5217,5559,6128,6223,6503,6609,11813,26862}
(1 row)

WITH Temp AS (
  SELECT DISTINCT TripId FROM q5_30
  EXCEPT
  SELECT DISTINCT TripId FROM tq5_30 )
SELECT array_agg(TripId ORDER BY TripId) from Temp;
              array_agg
-------------------------------------
{305,444,450,461,525,635,750,770,890,911,1200,1236,1252,1255,1257,1259,1262,1285,1630,2005,2064,2156,2259,2265,2410,245
6,2768,3056,3325,3784,3843,3970,4262,6194,6298,11398,11521,11571,25009,25164,25379,25422,25430,25480,25692,26594,26863,2
6874,26891}
(1 row)

*/
-------------------------------------------------------------------------------

/*
5.32. Trips where the Pm25 strictly increases continuously for at least
1.5 minutes, always with of values of Pm25 higher than 125, followed by a
strictly continuous decrease of at least 1.5 minutes, and such that in both
runs, the temperature was always higher than 20 degrees.

[(Pm25, @p), prev(Pm25) < @p, @p > '125', Duration(@p, @first) >= '5 minutes', (Temp, @tp), @tp > '20']+.
[(Pm25, @q), prev(Pm25) > @q, Duration(@q, @first2) >= '2 minutes', (Temp, @tq), @tq > '20']+
*/

DROP TABLE IF EXISTS Q5_32;
CREATE TABLE Q5_32 AS
WITH TripPm25Temp (TripId, T, Pm25, Temp, Trend) AS (
  SELECT TripId, T,
   (Attributes->>'Pm25')::numeric,
   (Attributes->>'Temperature')::numeric,
   CASE
    WHEN (Attributes->>'Pm25')::numeric > LAG((Attributes->>'Pm25')::numeric) 
     OVER (PARTITION BY TripId ORDER BY T) THEN  1
    WHEN (Attributes->>'Pm25')::numeric < LAG((Attributes->>'Pm25')::numeric) 
     OVER (PARTITION BY TripId ORDER BY T) THEN -1
    ELSE 0
   END
  FROM TripPoints),
Runs (TripId, T, Pm25, Temp, Trend, PrevTrend) AS (
  SELECT TripId, T, Pm25, Temp, Trend,
   LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25Temp
  WHERE Trend <> 0),
RunIds (TripId, RunId, T, Pm25, Temp, Trend) AS (
  SELECT TripId, SUM(
   CASE 
    WHEN Trend = PrevTrend THEN 0 ELSE 1 END) OVER (PARTITION BY TripId 
     ORDER BY T), T, Pm25, Temp, Trend
  FROM Runs),
RunStats (TripId, RunId, Trend, StartTime, EndTime, Duration, TempOK) AS (
 SELECT TripId, RunId, Trend, MIN(T), MAX(T),
  EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0, bool_and(Temp > 20),
         bool_and(Trend <> 1 OR Pm25 > 125)
  FROM RunIds
  GROUP BY TripId, RunId, Trend),
SelectedRuns (TripId, RunId, Trend, StartTime, EndTime, Duration) AS (
 SELECT TripId, RunId, Trend, StartTime, EndTime, Duration
 FROM RunStats
 WHERE TempOK AND ((Trend = 1 AND Duration >= 1.5) 
  OR (Trend = -1 AND Duration >= 1.5))),
RunBounds (TripId, RunId, Trend, StartTime, EndTime, Duration, StartPm25, EndPm25, 
 StartTemp, EndTemp) AS (
 SELECT DISTINCT ON (r.TripId, r.RunId) r.TripId, r.RunId, r.Trend, r.StartTime,
   r.EndTime, r.Duration, FIRST_VALUE(p.Pm25) OVER w, LAST_VALUE (p.Pm25) 
    OVER w, FIRST_VALUE(p.Temp) OVER w, LAST_VALUE (p.Temp) OVER w
 FROM SelectedRuns r, RunIds p
 WHERE p.TripId = r.TripId AND p.RunId  = r.RunId
  WINDOW w AS (PARTITION BY r.TripId, r.RunId ORDER BY p.T ROWS 
   BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  ORDER BY r.TripId, r.RunId),
IncDecPairs (TripId, IncRun, DecRun) AS (
  SELECT r1.TripId, r1.RunId, r2.RunId
  FROM RunBounds r1, RunBounds r2
  WHERE r2.TripId = r1.TripId AND r2.RunId  = r1.RunId + 1
   AND r1.Trend  =  1 AND r2.Trend  = -1)
SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime, r.Duration, r.StartPm25, 
 r.EndPm25, r.StartTemp, r.EndTemp
FROM RunBounds r, IncDecPairs p
WHERE p.TripId = r.TripId AND r.RunId IN (p.IncRun, p.DecRun)
ORDER BY r.TripId, r.RunId;

-- 18 rows (9 trips)
-- 3min 11secs
-- select distinct (tripid) from Q5_32_PB;3265, 5098, 3226, 6254, 6284,
-- 26611, 26738, 25774, 545

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_32;
CREATE TABLE TQ5_32 AS
WITH TripSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips ),
TripSegmWeather(TripId, Segm, Weather) AS (
  SELECT TripId, Segm, w.Weather
  FROM TripSegments t, WeatherHourly w
  WHERE date_trunc('hour', startTimestamp(t.Segm)) = w.Time ),
TripSegmTrend(TripId, Trend, T) AS (
  SELECT TripId,
    CASE
      WHEN startValue(Segm) < endValue(Segm) THEN 'I'
      WHEN startValue(Segm) > endValue(Segm) THEN 'D'
      ELSE 'C'
    END, startTimestamp(Segm), Weather
    FROM TripSegmWeather
    WHERE startValue(Segm) > 125 AND
      (Weather->>'Temperature')::numeric > 20 ),
TripTrend(TripId, Trend) AS (
  SELECT TripId, ttextSeq(array_agg(ttext(Trend, T) ORDER BY T))
  FROM TripSegmTrend
  GROUP BY TripId ),
TrendSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Trend))
  FROM TripTrend ),
TripSegmLabel(TripId, Label, T) AS (
  SELECT TripId,
    CASE
      WHEN startValue(Segm) = 'I' AND duration(Segm) > '5 min' THEN 'A'
      WHEN startValue(Segm) = 'D' AND duration(Segm) > '2 min' THEN 'B'
      ELSE 'X'
    END, startTimestamp(Segm)
  FROM TrendSegments ),
TripLabel(TripId, Label) AS (
  SELECT TripId, ttextSeq(array_agg(ttext(Label, T) ORDER BY T))
  FROM TripSegmLabel
  GROUP BY TripId ),
TripPattern(TripId, Pat) AS (
  SELECT TripId, string_agg(getValue(i.inst), '' ORDER BY i.Inst)
  FROM TripLabel, LATERAL unnest(instants(Label)) AS i(Inst)
  GROUP BY TripId )
SELECT *
FROM TripPattern
WHERE Pat ~ 'AB'
ORDER BY Tripid;

-- SELECT 1
-- Time: 5873.400 ms (00:05.873)

-------------------------------------------------------------------------------

/*
Query 5.35.  Trips where PM25 is already < 100 at the beginning OR
first drops below 100, and then later  exceeds 400 at some point.

[ (Pm25, @p), @p < '130' ]* . [ (Pm25, @q), @q > '180' ]
*/

WITH SelectedTrips(TripId) AS (
  SELECT TripId
  FROM TripPoints
  GROUP BY TripId
  HAVING MIN((Attributes->>'Pm25')::numeric) < 130 AND
    MAX((Attributes->>'Pm25')::numeric) > 180 )
SELECT p.TripId, MIN(p.T) AS StartTime, MAX(p.T) AS EndTime,
  array_agg((p.Attributes->>'Pm25')::numeric ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, SelectedTrips s
WHERE p.TripId = s.TripId
GROUP BY p.TripId
ORDER BY p.TripId;

-- 196 rows 
-- 35 secs

-------------------------------------------------------------------------------
 
/*
Query 5.36. Same as Query~\ref{que:query-535PB}, but such that the elapsed time between the increase of values in less than five minutes.

[(Pm25, @p), @p < '130'].
[(Pm25, @q), @q > '180', Duration(@q, @p) < '30 minutes']
*/

WITH TripTimes(TripId, TimeBelow130, TimeAbove180) AS (
  SELECT TripId, MIN(CASE WHEN Pm25 < 130 THEN T END),
    MIN(CASE WHEN Pm25 > 180 THEN T END)
  FROM TripPoints
  GROUP BY TripId ),
SelectedTrips(TripId, TimeBelow130, TimeAbove180, MinutesTo180) AS (
  SELECT *, EXTRACT(EPOCH FROM (TimeAbove180 - TimeBelow130)) / 60.0
  FROM TripTimes
  WHERE TimeBelow130 IS NOT NULL  AND TimeAbove180 IS NOT NULL AND
    EXTRACT(EPOCH FROM (TimeAbove180 - TimeBelow130)) / 60.0 < 30 )
SELECT p.TripId, MIN(p.T) AS StartTime, MAX(p.T) AS EndTime,
  array_agg(p.Pm25 ORDER BY p.T) AS Pm25Seq, s.MinutesTo180
FROM TripPoints p, SelectedTrips s
WHERE p.TripId = s.TripId
GROUP BY p.TripId, s.MinutesTo180
ORDER BY p.TripId;

-- 26 rows 
-- 22 secs
-------------------------------------------------------------------------------

/*
Query 5.37. Trips traveling all their way under a temperature higher
than 25 degrees and such that at in at least any two Runs longer than ten minutes, the Pm25 was higher than 150.

[ (Pm25, @p1), @p1 > '150', Duration(@p1, @first1) > '2 minutes', (Temp, @t1), @t1 > '20' ]+ .
[ (Pm25, @p2), @p2 > '150', Duration(@p2, @first2) > '2 minutes', (Temp, @t2), @t2 > '20' ]+
*/

WITH
ValidTrips (TripId) AS (
  SELECT TripId
  FROM TripPoints
  GROUP BY TripId
  HAVING MIN((Attributes->>'Temperature')::numeric) > 25),
-- All points of valid trips (not filter of PM25 here)
TripPm25 (TripId, T, Pm25) AS (
  SELECT TripId, T, (Attributes->>'Pm25')::numeric
  FROM TripPoints
  WHERE TripId IN (SELECT TripId FROM ValidTrips)),
-- Identify breaks between runs with  PM25 > 150 
Runs (TripId, T, Pm25, BreakRun) AS (
  SELECT TripId, T, Pm25,
    CASE
     WHEN Pm25 <= 150 
      OR LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) <= 150
     THEN 1 ELSE 0
    END
  FROM TripPm25),
-- Assign run ids
RunIds (TripId, RunId, T, Pm25) AS (
  SELECT TripId, SUM(BreakRun) OVER (PARTITION BY TripId ORDER BY T), T,  Pm25
  FROM Runs),
-- Compute run duration correctly
RunTimes (TripId, RunId, StartTime, EndTime, Duration, NumPoints) AS (
  SELECT TripId, RunId, MIN(T), MAX(T),
   EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0, COUNT(*)
  FROM RunIds
  WHERE Pm25 > 150
  GROUP BY TripId, RunId),
-- Keep only valid runs (>= 2 minutes, >=2 points)
ValidRuns (TripId, RunId, StartTime, EndTime, Duration) AS (
  SELECT TripId, RunId, StartTime, EndTime, Duration
  FROM RunTimes
  WHERE Duration >= 10 AND NumPoints >= 2),
-- Trips having at least two valid runs
QualifiedTrips (TripId) AS (
  SELECT TripId
  FROM ValidRuns
  GROUP BY TripId
  HAVING COUNT(*) >= 2 )

-- Final result with only satisfying runs
SELECT v.TripId, v.RunId, v.StartTime, v.EndTime, v.Duration
FROM ValidRuns v, QualifiedTrips q
WHERE v.TripId = q.TripId
ORDER BY v.TripId, v.StartTime;

--  8 rows 
--  28 secs

-------------------------------------------------------------------------------
/*
Query 5.38.  Trips such that there is at least a 30-minutes run where
Pm25 was continuously higher than 300  in cloudy conditions, and
with Humidity higher than 80%.

[ (Pm25, @p), @p > '150', Duration(@p, @first) >= '20 minutes',
  (CloudCover, @cc), @cc > '0', (Humidity, @h), @h > '70']+
*/

WITH Filtered (TripId, T, Pm25, CloudCover, Humidity, Valid) AS (
 SELECT TripId, T,
  (Attributes->>'Pm25')::numeric,
  (Attributes->>'CloudCover')::numeric,
  (Attributes->>'Humidity')::numeric,
  CASE
   WHEN (Attributes->>'Pm25')::numeric > 300  AND 
   	(Attributes->>'CloudCover')::numeric > 0 AND 
   	(Attributes->>'Humidity')::numeric > 80
   THEN 1 ELSE 0
   END
  FROM TripPoints),
-- build runs using gaps-and-islands on Valid
Runs (TripId, T, Pm25, CloudCover, Humidity, RunId) AS (
 SELECT TripId, T, Pm25, CloudCover, Humidity,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY T) - 
     ROW_NUMBER() OVER (PARTITION BY TripId, Valid ORDER BY T)
  FROM Filtered
  WHERE Valid = 1),
-- compute run bounds and duration
RunTimes (TripId, RunId, StartTime, EndTime, Duration, Pm25Seq, CloudCoverSeq, 
 HumiditySeq) AS (
  SELECT TripId, RunId, MIN(T), MAX(T), 
   EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0,
  array_agg(Pm25 ORDER BY T),
  array_agg(CloudCover ORDER BY T),
  array_agg(Humidity ORDER BY T)
  FROM Runs
  GROUP BY TripId, RunId)
-- keep only runs lasting at least 30  minutes
SELECT TripId, RunId, StartTime, EndTime, Duration, Pm25Seq, CloudCoverSeq,
 HumiditySeq
FROM RunTimes
WHERE Duration >= 30
ORDER BY TripId, StartTime;

--  130 rows 
--  19 secs

-------------------------------------------------------------------------------


[249@2020-12-07 09:53:04+05:30, 248@2020-12-07 09:53:07+05:30)

"2020-12-07 10:04:49+05:30"
"2020-12-07 10:09:43+05:30"
"2020-12-07 10:09:46+05:30"
"2020-12-07 10:11:11+05:30"
