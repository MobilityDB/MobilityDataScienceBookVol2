
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


[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '1.5 minutes' ]+
[ (Pm25, @q), prev(Pm25) > @q, Duration(@p, @first) >= '1.5 minutes' ]+

*/

DROP TABLE IF EXISTS Q5_30_lag;
CREATE TABLE Q5_30_lag AS 
WITH TripPm25 (TripId, T, PrevT, Pm25, PrevPm25, Trend) AS (
  SELECT TripId, T, LAG(T) OVER w, Pm25, LAG(Pm25) OVER w,
    CASE
      WHEN Pm25 > LAG(Pm25) OVER w THEN  1 
      WHEN Pm25 < LAG(Pm25) OVER w THEN -1
      ELSE 0
    END
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Phases (TripId, T, PrevT, Pm25, PrevPm25, Trend, PrevTrend) AS (
  SELECT TripId, T, PrevT, Pm25, PrevPm25, Trend,
    LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25 ),
PhaseIds (TripId, PhaseId, T, PrevT, Pm25, PrevPm25, Trend) AS (
  SELECT TripId, SUM(CASE WHEN Trend = PrevTrend THEN 0 ELSE 1 END) OVER
    (PARTITION BY TripId ORDER BY T), T, PrevT, Pm25, PrevPm25, Trend
  FROM Phases ),
PhaseTimes (TripId, PhaseId, Trend, StartTime, EndTime, StartPm25, EndPm25,
    Duration) AS (
  SELECT TripId, PhaseId, Trend, MIN(PrevT), MAX(T), MIN(PrevPm25), MAX(Pm25),
    EXTRACT(EPOCH FROM MAX(T) - MIN(PrevT)) / 60.0
  FROM PhaseIds
  GROUP BY TripId, PhaseId, Trend
  HAVING EXTRACT(EPOCH FROM MAX(T) - MIN(PrevT)) / 60.0 >= 1.5 ),
SelectedPhases (TripId, IncPhase, DecPhase) AS (
  SELECT r1.TripId, r1.PhaseId AS IncPhase, r2.PhaseId AS DecPhase
  FROM PhaseTimes r1, PhaseTimes r2
  WHERE r1.TripId = r2.TripId AND r1.Trend = 1 AND r2.Trend = -1 AND
    r1.EndTime = r2.StartTime )
SELECT r.TripId, r.PhaseId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25
FROM PhaseTimes r, SelectedPhases s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncPhase, s.DecPhase)
ORDER BY r.TripId, r.PhaseId;

-- SELECT 138
-- Time: 33587.475 ms (00:33.587)

DROP TABLE IF EXISTS Q5_30;
CREATE TABLE Q5_30 AS 
WITH TripPm25(TripId, T, NextT, Pm25, NextPm25, Trend) AS (
  SELECT TripId, T, LEAD(T) OVER w, Pm25, LEAD(Pm25) OVER w,
    SIGN((LEAD(Pm25) OVER w) - Pm25) /* Compute the trend */
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Phases(TripId, T, NextT, Pm25, NextPm25, Trend, PrevTrend) AS (
  SELECT TripId, T, NextT, Pm25, NextPm25, Trend,
    LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25 ),
PhaseIds(TripId, PhaseId, T, NextT, Pm25, NextPm25, Trend) AS (
  SELECT TripId, SUM(CASE WHEN Trend = PrevTrend THEN 0 ELSE 1 END)
      OVER (PARTITION BY TripId ORDER BY T) AS PhaseId,
    T, NextT, Pm25, NextPm25, Trend
  FROM Phases
  WHERE NextT IS NOT NULL ),
PhaseTimes(TripId, PhaseId, Trend, StartTime, EndTime, StartPm25, EndPm25) AS (
  SELECT TripId, PhaseId, Trend, MIN(T), MAX(NextT), MIN(Pm25), MAX(NextPm25),
    EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 AS Duration
  FROM PhaseIds
  GROUP BY TripId, PhaseId, Trend
  HAVING EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 >= 1.5 ),
SelectedPhases(TripId, IncPhase, DecPhase) AS (
  SELECT i.TripId, i.PhaseId, d.PhaseId
  FROM PhaseTimes i, PhaseTimes d
  WHERE i.TripId = d.TripId AND i.Trend = 1 AND d.Trend = -1 AND 
    i.EndTime = d.StartTime )
SELECT r.TripId, r.PhaseId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25
FROM PhaseTimes r, SelectedPhases s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncPhase, s.DecPhase)
ORDER BY r.TripId, r.PhaseId;

-- SELECT 138
-- Time: 34334.682 ms (00:34.335)

--------------------------------------------------------------

SELECT DISTINCT TripId FROM q5_30_lag EXCEPT SELECT DISTINCT TripId FROM q5_30;

SELECT DISTINCT TripId FROM q5_30 EXCEPT SELECT DISTINCT TripId FROM q5_30_lag;

--------------------------------------------------------------

DROP TABLE IF EXISTS TQ5_30;
CREATE TABLE TQ5_30 AS 
WITH IncPhases(TripId, Inc) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #> 0, true),
      interval '1.5 minute', false))))
  FROM DelhiTrips ),
DecPhases(TripId, Dec) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #< 0, true),
      interval '1.5 minute', false))))
  FROM DelhiTrips )
SELECT i.TripId, i.Inc, d.Dec
FROM IncPhases i, DecPhases d
WHERE i.TripId = d.TripId AND upper(Inc) = lower(Dec);

-- SELECT 69
-- Time: 1762.925 ms (00:01.763)

-------------------------------------------------------------------------------

/*
5.32. Trips where the Pm25 strictly increases continuously for at least
1.5 minutes, always with of values of Pm25 higher than 125, followed by a
strictly continuous decrease of at least 1.5 minutes, and such that in both
runs, the temperature was always higher than 20 degrees.

[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '1.5 minutes',
    @p > '125', (Temp, @tp), @tp > '20']+
[ (Pm25, @q), prev(Pm25) > @q, Duration(@q, @first) >= '1.5 minutes',
    @p > '125', (Temp, @tq), @tq > '20']+
*/

DROP TABLE IF EXISTS Q5_32;
CREATE TABLE Q5_32 AS
WITH TripSegments(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp) AS (
  SELECT TripId, T, LEAD(T) OVER w, Pm25, LEAD(Pm25) OVER w,
    (Attributes->>'Temperature')::numeric,
    ((LEAD(Attributes) OVER w)->>'Temperature')::numeric
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
ClippedSegments(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp) AS (
  SELECT TripId,
    CASE  /* clipped start time */
      WHEN Pm25 >= 125 THEN T ELSE CrossT
    END,
    CASE  /* clipped end time */
      WHEN nextPm25 >= 125 THEN NextT ELSE CrossT
    END,
    GREATEST(Pm25, 125),     /* clipped start value */
    GREATEST(nextPm25, 125), /* clipped end value */
    Temp, NextTemp /* We suppose that we do not interpolate temperature */
  FROM (
    SELECT *,
      CASE
        WHEN (Pm25 < 125 AND nextPm25 > 125) OR (Pm25 > 125 AND nextPm25 < 125)
        THEN T + (125 - Pm25) / NULLIF(nextPm25 - Pm25, 0) * (nextT - T)
      END AS CrossT
    FROM TripSegments
    WHERE nextT IS NOT NULL ) s
  WHERE GREATEST(Pm25, nextPm25) > 125 ),
SegmentsTrend (TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend) AS (
  SELECT TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp,
    SIGN(nextPm25 - Pm25) /* Compute the trend */
  FROM ClippedSegments
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Phases(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend, PrevTrend) AS (
  SELECT TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend,
    LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM SegmentsTrend ),
PhaseIds(TripId, PhaseId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend) AS (
  SELECT TripId, SUM(CASE WHEN Trend = PrevTrend THEN 0 ELSE 1 END) OVER
    (PARTITION BY TripId ORDER BY T), T, NextT, Pm25, NextPm25, Temp,
    NextTemp, Trend
  FROM Phases ),
PhaseTimes(TripId, PhaseId, Trend, StartTime, EndTime, StartPm25, EndPm25,
    StartTemp, EndTemp, Duration) AS (
  SELECT TripId, PhaseId, Trend, MIN(T), MAX(NextT), MIN(Pm25), MAX(NextPm25),
    MIN(Temp), MAX(NextTemp), EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0
  FROM PhaseIds
  GROUP BY TripId, PhaseId, Trend
  HAVING bool_and(LEAST(NextTemp, Temp) > 20) AND
    EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 >= 1.5 ),
SelectedPhases(TripId, IncPhase, DecPhase) AS (
  SELECT r1.TripId, r1.PhaseId AS IncPhase, r2.PhaseId AS DecPhase
  FROM PhaseTimes r1, PhaseTimes r2
  WHERE r1.TripId = r2.TripId AND r1.Trend = 1 AND r2.Trend = -1 AND
    r1.EndTime = r2.StartTime )
SELECT r.TripId, r.PhaseId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25, r.StartTemp, r.EndTemp
FROM PhaseTimes r, SelectedPhases s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncPhase, s.DecPhase)
ORDER BY r.TripId, r.PhaseId;

-- SELECT 38
-- Time: 86101.517 ms (01:26.102)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_32;
CREATE TABLE TQ5_32 AS
WITH TripsTime(TripId, Time) AS (
  SELECT t.TripId, whenTrue(PM2_5 #> 125) * 
    whenTrue(tfloat(Weather, 'Temperature', 'step') #> 20)
  FROM DelhiTrips t, TripsWeather w
  WHERE t.TripId = w.TripId AND whenTrue(PM2_5 #> 125) IS NOT NULL AND
    whenTrue(tfloat(Weather, 'Temperature') #> 20) IS NOT NULL ),
FilteredTrips(TripId, Pm2_5) AS (
  SELECT d.TripId, atTime(Pm2_5, Time)
  FROM DelhiTrips d, TripsTime t
  WHERE d.TripId = t.TripId ),
IncPhases(TripId, Inc) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #> 0, true),
      interval '1.5 minute', false))))
  FROM FilteredTrips ),
DecPhases(TripId, Dec) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #< 0, true),
      interval '1.5 minute', false))))
  FROM FilteredTrips )
SELECT i.TripId, i.Inc, d.Dec
FROM IncPhases i, DecPhases d
WHERE i.TripId = d.TripId AND upper(Inc) = lower(Dec);

-- SELECT 20
-- Time: 9999.235 ms (00:09.999)

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
than 25 degrees and such that at in at least any two Phases longer than ten minutes, the Pm25 was higher than 150.

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
Phases (TripId, T, Pm25, BreakPhase) AS (
  SELECT TripId, T, Pm25,
    CASE
     WHEN Pm25 <= 150 
      OR LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) <= 150
     THEN 1 ELSE 0
    END
  FROM TripPm25),
-- Assign run ids
PhaseIds (TripId, PhaseId, T, Pm25) AS (
  SELECT TripId, SUM(BreakPhase) OVER (PARTITION BY TripId ORDER BY T), T,  Pm25
  FROM Phases),
-- Compute run duration correctly
PhaseTimes (TripId, PhaseId, StartTime, EndTime, Duration, NumPoints) AS (
  SELECT TripId, PhaseId, MIN(T), MAX(T),
   EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0, COUNT(*)
  FROM PhaseIds
  WHERE Pm25 > 150
  GROUP BY TripId, PhaseId),
-- Keep only valid runs (>= 2 minutes, >=2 points)
ValidPhases (TripId, PhaseId, StartTime, EndTime, Duration) AS (
  SELECT TripId, PhaseId, StartTime, EndTime, Duration
  FROM PhaseTimes
  WHERE Duration >= 10 AND NumPoints >= 2),
-- Trips having at least two valid runs
QualifiedTrips (TripId) AS (
  SELECT TripId
  FROM ValidPhases
  GROUP BY TripId
  HAVING COUNT(*) >= 2 )

-- Final result with only satisfying runs
SELECT v.TripId, v.PhaseId, v.StartTime, v.EndTime, v.Duration
FROM ValidPhases v, QualifiedTrips q
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
Phases (TripId, T, Pm25, CloudCover, Humidity, PhaseId) AS (
 SELECT TripId, T, Pm25, CloudCover, Humidity,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY T) - 
     ROW_NUMBER() OVER (PARTITION BY TripId, Valid ORDER BY T)
  FROM Filtered
  WHERE Valid = 1),
-- compute run bounds and duration
PhaseTimes (TripId, PhaseId, StartTime, EndTime, Duration, Pm25Seq, CloudCoverSeq, 
 HumiditySeq) AS (
  SELECT TripId, PhaseId, MIN(T), MAX(T), 
   EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0,
  array_agg(Pm25 ORDER BY T),
  array_agg(CloudCover ORDER BY T),
  array_agg(Humidity ORDER BY T)
  FROM Phases
  GROUP BY TripId, PhaseId)
-- keep only runs lasting at least 30  minutes
SELECT TripId, PhaseId, StartTime, EndTime, Duration, Pm25Seq, CloudCoverSeq,
 HumiditySeq
FROM PhaseTimes
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
