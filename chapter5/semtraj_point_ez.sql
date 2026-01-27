
SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';
  
DROP TABLE IF EXISTS TripPoints;
CREATE TABLE TripPoints(TripId integer, T timestamptz, Pm1_0 float, Pm2_5 float,
  Pm10 float, Geom geometry, Weather jsonb, PRIMARY KEY(TripId, T));
INSERT INTO TripPoints
WITH DelhiStart(DeviceId, T, Pm1_0, Pm2_5, Pm10, Geom, StartInst) AS (
  SELECT DeviceId, T, Pm1_0, Pm2_5, Pm10, Geom,
    CASE 
      WHEN LAG(T) OVER w IS NULL OR T - LAG(T) OVER w > '5 minutes' OR
        ST_Distance(Geom, LAG(Geom) OVER w) > 1000 THEN 1
    END
  FROM DelhiInput
  WINDOW w AS (PARTITION BY DeviceId ORDER BY T) ),
DelhiGroup(TripId, T, Pm1_0, Pm2_5, Pm10, Geom) AS (
  SELECT COUNT(StartInst) OVER (ORDER BY DeviceId, T), T, Pm1_0, Pm2_5, Pm10,
    Geom 
  FROM DelhiStart )
SELECT g.TripId, g.T, g.Pm2_5, g.Pm1_0, g.Pm10, g.Geom, w.Weather
FROM DelhiGroup g, WeatherHourly w
WHERE date_trunc('hour', g.T) = w.T
ORDER BY TripId;

-- INSERT 0 7087619
-- Time: 145731.315 ms (02:25.731)

CREATE INDEX TripPoints_Geom_Idx ON TripPoints USING SPGIST(Geom);

-- Time: 60202.869 ms (01:00.203)

------------------------------------------------------------------------------

/*
Query 5.29. Trips where the Pm25 increases throughout the entire trip

[ (Pm25, @p), prev(Pm25) < @p ]
*/

DROP TABLE IF EXISTS Q5_29;
CREATE TABLE Q5_29 AS
WITH Segments(TripId, T, Pm25, NextPm25) AS (
  SELECT TripId, T, Pm25, LEAD(Pm25) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPoints )
SELECT TripId, MIN(T) AS StartTime, MAX(T) AS EndTime,
  array_agg(Pm25 ORDER BY T) AS Pm25Seq
FROM Segments
WHERE NextPm25 IS NOT NULL
GROUP BY TripId
HAVING bool_and(Pm25 < NextPm25)
ORDER BY TripId, StartTime;

-- SELECT 708
-- Time: 14675.736 ms (00:14.676)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_29;
CREATE TABLE TQ5_29 AS
WITH Segments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips
  WHERE numInstants(Pm2_5) > 1 )
SELECT TripId, Pm2_5
FROM DelhiTrips
WHERE numInstants(Pm2_5) > 1 AND tripId NOT IN (
  SELECT DISTINCT TripId
  FROM Segments
  WHERE startValue(Segm) >= endValue(Segm) );

-- SELECT 608
-- Time: 3404.372 ms (00:03.404)

-------------------------------------------------------------------------------

SELECT DISTINCT TripId FROM tq5_29 EXCEPT SELECT DISTINCT TripId FROM q5_29;
-- 161 ROWS

SELECT DISTINCT TripId FROM q5_29 EXCEPT SELECT DISTINCT TripId FROM tq5_29;
-- 261 ROWS

------------------------------------------------------------------------------

/*
Query 5.30. Trips have at least a continuous phase of 1.5 minutes
with strictly increasing Pm25, followed by a continuous phase of
1.5 minutes with strictly decreasing Pm25.

[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '1.5 minutes' ]+
[ (Pm25, @q), prev(Pm25) > @q, Duration(@p, @first) >= '1.5 minutes' ]+

*/

DROP TABLE IF EXISTS Q5_30;
CREATE TABLE Q5_30 AS 
WITH Trends(TripId, T, NextT, Pm25, NextPm25, Trend) AS (
  SELECT TripId, T, LEAD(T) OVER w, Pm25, LEAD(Pm25) OVER w,
    SIGN((LEAD(Pm25) OVER w) - Pm25)
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
PhaseStarts(TripId, T, NextT, Pm25, NextPm25, Trend, NewPhase) AS (
  SELECT *,
    CASE
      WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
        THEN 0 ELSE 1
    END
  FROM Trends ),
  -- WHERE Trend <> 0 ),
Phases(TripId, PhaseId, T, NextT, Pm25, NextPm25, Trend) AS (
  SELECT TripId, SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY T), 
    T, NextT, Pm25, NextPm25, Trend
  FROM PhaseStarts ),
PhaseTimes(TripId, PhaseId, Trend, StartTime, EndTime, StartPm25, EndPm25,
    Duration) AS (
  SELECT TripId, PhaseId, Trend, MIN(T), MAX(NextT), MIN(Pm25), MAX(NextPm25),
    EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 AS Duration
  FROM Phases
  GROUP BY TripId, PhaseId, Trend
  HAVING EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 >= 1.5 ),
SelectedPhases(TripId, IncrPhase, DecrPhase) AS (
  SELECT i.TripId, i.PhaseId, d.PhaseId
  FROM PhaseTimes i, PhaseTimes d
  WHERE i.TripId = d.TripId AND i.Trend = 1 AND d.Trend = -1 AND 
    i.EndTime = d.StartTime )
SELECT r.TripId, r.PhaseId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25
FROM PhaseTimes r, SelectedPhases s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncrPhase, s.DecrPhase)
ORDER BY r.TripId, r.PhaseId;

-- SELECT 138 vs 182 depending on whether we filter with WHERE Trend <> 0
-- Time: 33946.904 ms (00:33.947)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_30;
CREATE TABLE TQ5_30 AS 
WITH IncrPhases(TripId, Incr) AS (
  SELECT TripId, unnest(spans(whenTrue(segmentMinDuration(
    atValues(trend(Pm2_5) #> 0, true), interval '1.5 minute', false))))
  FROM DelhiTrips ),
DecrPhases(TripId, Decr) AS (
  SELECT TripId, unnest(spans(whenTrue(segmentMinDuration(
    atValues(trend(Pm2_5) #< 0, true), interval '1.5 minute', false))))
  FROM DelhiTrips )
SELECT i.TripId, i.Incr, d.Decr
FROM IncrPhases i, DecrPhases d
WHERE i.TripId = d.TripId AND upper(Incr) = lower(Decr);

-- SELECT 69
-- Time: 1762.925 ms (00:01.763)

-------------------------------------------------------------------------------

SELECT DISTINCT TripId FROM tq5_30 EXCEPT SELECT DISTINCT TripId FROM q5_30;
-- (0 rows)

SELECT DISTINCT TripId FROM q5_30 EXCEPT SELECT DISTINCT TripId FROM tq5_30;
-- (0 rows)

-------------------------------------------------------------------------------

/*
5.31. Trips where the Pm25 strictly increases continuously for at least
1.5 minutes, followed by a strictly continuous decrease of at least
1.5 minutes, and such that in both phases, the values of Pm25 are higher
than 125 and the temperature was always higher than 20 degrees.

[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '1.5 minutes',
    @p > '125', (Temp, @tp), @tp > '20']+
[ (Pm25, @q), prev(Pm25) > @q, Duration(@q, @first) >= '1.5 minutes',
    @p > '125', (Temp, @tq), @tq > '20']+
*/

DROP TABLE IF EXISTS Q5_31;
CREATE TABLE Q5_31 AS
WITH Segments(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp) AS (
  SELECT TripId, T, LEAD(T) OVER w, Pm25, LEAD(Pm25) OVER w,
    (Weather->>'Temperature')::numeric,
    ((LEAD(Weather) OVER w)->>'Temperature')::numeric
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Crossings(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, CrossT) AS (
  SELECT *,
    CASE
      WHEN (Pm25 < 125 AND 125 < nextPm25)
        THEN T + (NextT - T) * (125 - Pm25) / (nextPm25 - Pm25) 
      WHEN (Pm25 > 125 AND 125 > nextPm25)
        THEN T + (NextT - T) * (Pm25 - 125) / (Pm25 - nextPm25)
    END
  FROM Segments
  WHERE NextT IS NOT NULL ),
ClippedSegments(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp) AS (
  SELECT TripId,
    /* clipped start and end time */
    CASE WHEN Pm25 >= 125 THEN T ELSE CrossT END, 
    CASE WHEN NextPm25 >= 125 THEN NextT ELSE CrossT END,
    /* clipped start and end value */
    GREATEST(Pm25, 125), GREATEST(NextPm25, 125),
    Temp, NextTemp /* We suppose that we do not interpolate temperature */
  FROM Crossings
  WHERE GREATEST(Pm25, nextPm25) > 125 ),
Trends(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend) AS (
  SELECT TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp,
    SIGN(nextPm25 - Pm25)
  FROM ClippedSegments
  WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
PhaseStarts(TripId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend, NewPhase) AS (
  SELECT *,
    CASE
      WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
        THEN 0 ELSE 1
    END
  FROM Trends ),
  -- WHERE Trend <> 0 ),
Phases(TripId, PhaseId, T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend) AS (
  SELECT TripId, SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY T), 
    T, NextT, Pm25, NextPm25, Temp, NextTemp, Trend
  FROM PhaseStarts ),
PhaseTimes(TripId, PhaseId, Trend, StartTime, EndTime, StartPm25, EndPm25,
    StartTemp, EndTemp, Duration) AS (
  SELECT TripId, PhaseId, Trend, MIN(T), MAX(NextT), MIN(Pm25), MAX(NextPm25),
    MIN(Temp), MAX(NextTemp), EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0
  FROM Phases
  GROUP BY TripId, PhaseId, Trend
  HAVING bool_and(LEAST(NextTemp, Temp) >= 20) AND
    EXTRACT(EPOCH FROM MAX(NextT) - MIN(T)) / 60.0 >= 1.5 ),
SelectedPhases(TripId, IncrPhase, DecrPhase) AS (
  SELECT r1.TripId, r1.PhaseId AS IncrPhase, r2.PhaseId AS DecrPhase
  FROM PhaseTimes r1, PhaseTimes r2
  WHERE r1.TripId = r2.TripId AND r1.Trend = 1 AND r2.Trend = -1 AND
    r1.EndTime = r2.StartTime )
SELECT r.TripId, r.PhaseId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25, r.StartTemp, r.EndTemp
FROM PhaseTimes r, SelectedPhases s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncrPhase, s.DecrPhase)
ORDER BY r.TripId, r.PhaseId;

-- SELECT 46 vs 58 depending on WHERE Trend <> 0
-- Time: 51905.096 ms (00:51.905)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_31;
CREATE TABLE TQ5_31 AS
WITH TripsTime(TripId, Time) AS (
  SELECT t.TripId, whenTrue(PM25 #>= 125) * 
    whenTrue(tfloat(Weather, 'Temperature', 'step') #>= 20)
  FROM DelhiTrips t, TripsWeather w
  WHERE t.TripId = w.TripId AND whenTrue(PM25 #>= 125) IS NOT NULL AND
    whenTrue(tfloat(Weather, 'Temperature', 'step') #>= 20) IS NOT NULL ),
SelectedTrips(TripId, Pm2_5) AS (
  SELECT d.TripId, atTime(d.Pm2_5, t.Time)
  FROM DelhiTrips d, TripsTime t
  WHERE d.TripId = t.TripId ),
IncrPhases(TripId, Incr) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #> 0, true),
      interval '1.5 minute', false))))
  FROM SelectedTrips ),
DecrPhases(TripId, Decr) AS (
  SELECT TripId, unnest(spans(
    whenTrue(segmentMinDuration(atValues(trend(Pm2_5) #< 0, true),
      interval '1.5 minute', false))))
  FROM SelectedTrips )
SELECT i.TripId, i.Incr, d.Decr
FROM IncrPhases i, DecrPhases d
WHERE i.TripId = d.TripId AND upper(Incr) = lower(Decr)
ORDER BY 1,2;

-- SELECT 21
-- Time: 3836.423 ms (00:03.836)

-------------------------------------------------------------------------------

SELECT DISTINCT TripId FROM q5_31 EXCEPT SELECT DISTINCT TripId FROM tq5_31 ORDER BY 1;

   2210
   3226
   3265
   5098
  26293
  26611

SELECT DISTINCT TripId FROM tq5_31 EXCEPT SELECT DISTINCT TripId FROM q5_31 ORDER BY 1;

   1227
   1244
   4498
   6576

-------------------------------------------------------------------------------

/*
Query 5.32.  Trips where Pm25 is already < 100 at the beginning OR
first drops below 100, and then later exceeds 400 at some point.

[ (Pm25, @p), @p < '100' ]* .* [ (Pm25, @q), @q > '400' ]
*/

DROP TABLE IF EXISTS Q5_32;
CREATE TABLE Q5_32 AS
SELECT p.TripId, s.StartTime, e.EndTime,
  array_agg(p.pm25 ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, (
  SELECT TripId, MIN(T) AS StartTime
  FROM TripPoints
  WHERE pm25 < 100
  GROUP BY TripId ) s, LATERAL (
  SELECT MIN(T) AS EndTime
  FROM TripPoints
  WHERE TripId = s.TripId AND pm25 > 400 AND T > s.StartTime ) e
WHERE p.TripId = s.TripId AND p.T BETWEEN s.StartTime AND e.EndTime
GROUP BY p.TripId, s.StartTime, e.EndTime
ORDER BY p.TripId;

-- SELECT 244
-- Time: 3176.022 ms (00:03.176)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_32;
CREATE TABLE TQ5_32 AS
WITH TripStarts(TripId, StartTime, Pm25) AS (
  SELECT TripId, lower(whenTrue(Pm25 #< 100)),
    afterTimestamp(Pm25, lower(whenTrue(Pm25 #< 100)), false)
  FROM Trips
  WHERE whenTrue(Pm25 #< 100) IS NOT NULL )
SELECT TripId, startInstant(Pm25) AS StartInstant, 
  startInstant(atTime(Pm25, lower(whenTrue(Pm25 #> 400)))) AS EndInstant
FROM TripStarts
WHERE StartTime IS NOT NULL AND whenTrue(Pm25 #> 400) IS NOT NULL;

-- SELECT 244
-- Time: 5971.121 ms (00:05.971)

-------------------------------------------------------------------------------

SELECT DISTINCT tripid FROM tq5_32 EXCEPT SELECT DISTINCT tripid FROM q5_32 ORDER BY 1 LIMIT 5;
   6254 

SELECT DISTINCT tripid FROM q5_32 EXCEPT SELECT DISTINCT tripid FROM tq5_32 ORDER BY 1 LIMIT 5;
      1
    198
    201
    242
    280

-------------------------------------------------------------------------------
 
/*
Query 5.33. Same as Query~\ref{que:query-535PB}, but such that the elapsed time between the increase of values in less than thirty minutes.

[(Pm25, @p), @p < '100'].
[(Pm25, @q), @q > '400', Duration(@q, @p) < '30 minutes']
*/

DROP TABLE IF EXISTS Q5_33;
CREATE TABLE Q5_33 AS
SELECT p.TripId, s.StartTime, e.EndTime,
  array_agg(p.pm25 ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, (
  SELECT TripId, MIN(T) AS StartTime
  FROM TripPoints
  WHERE pm25 < 100
  GROUP BY TripId ) s, LATERAL (
  SELECT MIN(T) AS EndTime
  FROM TripPoints
  WHERE TripId = s.TripId AND pm25 > 400 AND T > s.StartTime ) e
WHERE p.TripId = s.TripId AND p.T BETWEEN s.StartTime AND e.EndTime AND 
  EXTRACT(EPOCH FROM (EndTime - StartTime)) / 60.0 < 30 
GROUP BY p.TripId, s.StartTime, e.EndTime
ORDER BY p.TripId;

-- SELECT 94
-- Time: 1371.099 ms (00:01.371)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_33;
CREATE TABLE TQ5_33 AS
WITH TripStarts(TripId, StartTime, Pm25) AS (
  SELECT TripId, lower(whenTrue(Pm25 #< 100)),
    afterTimestamp(Pm25, lower(whenTrue(Pm25 #< 100)), false)
  FROM Trips
  WHERE whenTrue(Pm25 #< 100) IS NOT NULL )
SELECT TripId, startInstant(Pm25) AS StartInstant, 
  startInstant(atTime(Pm25, lower(whenTrue(Pm25 #> 400)))) AS EndInstant
FROM TripStarts
WHERE StartTime IS NOT NULL AND whenTrue(Pm25 #> 400) IS NOT NULL AND
  lower(whenTrue(Pm25 #> 400)) - StartTime < interval '30 minutes' ;

-- SELECT 94
-- Time: 5748.688 ms (00:05.749)

-------------------------------------------------------------------------------

SELECT DISTINCT tripid FROM tq5_33 EXCEPT SELECT DISTINCT tripid FROM q5_33 ORDER BY 1 LIMIT 5;
-- (0 rows)

SELECT DISTINCT tripid FROM q5_33 EXCEPT SELECT DISTINCT tripid FROM tq5_33 ORDER BY 1 LIMIT 5;
-- (0 rows)

-------------------------------------------------------------------------------

/*
Query 5.34. Trips traveling all their way under a temperature higher than
25 degrees and such that at in at least two sections longer than ten minutes,
the Pm25 was higher than 150.

[ (Pm25, @p1), @p1 > '150', Duration(@p1, @first1) > '10 minutes', (Temp, @t1), @t1 > '25' ]+ .
[ (Pm25, @p2), @p2 > '150', Duration(@p2, @first2) > '10 minutes', (Temp, @t2), @t2 > '25' ]+
*/

DROP TABLE IF EXISTS Q5_34;
CREATE TABLE Q5_34 AS
WITH FilteredTrips(TripId) AS (
  SELECT TripId 
  FROM TripPoints
  GROUP BY TripId
  HAVING MIN((Weather->>'Temperature')::numeric) > 25 ),
PhaseStarts(TripId, T, Pm25, StartPhase) AS (
  SELECT TripId, T, Pm25,
    CASE
      WHEN Pm25 <= 150 OR LAG(Pm25) OVER
        (PARTITION BY TripId ORDER BY T) <= 150
      THEN 1 ELSE 0
    END
  FROM TripPoints
  WHERE TripId IN (SELECT TripId FROM FilteredTrips) ),
Phases(TripId, PhaseId, T, Pm25) AS (
  SELECT TripId, SUM(StartPhase) OVER (PARTITION BY TripId ORDER BY T),
    T, Pm25
  FROM PhaseStarts ),
SelectedPhases(TripId, PhaseId, StartTime, EndTime, Duration, NumPoints) AS (
  SELECT TripId, PhaseId, MIN(T), MAX(T),
    EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0, COUNT(*)
  FROM Phases
  WHERE Pm25 > 150
  GROUP BY TripId, PhaseId
  HAVING EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0 >= 10 AND
    COUNT(*) >= 2 ),
SelectedTrips(TripId) AS (
  SELECT TripId
  FROM SelectedPhases
  GROUP BY TripId
  HAVING COUNT(*) >= 2 )
SELECT TripId, PhaseId, StartTime, EndTime, Duration
FROM SelectedPhases 
WHERE TripId IN (SELECT TripId FROM SelectedTrips)
ORDER BY TripId, StartTime;

--  SELECT 8
-- Time: 2968.922 ms (00:02.969)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_34;
CREATE TABLE TQ5_34 AS
WITH ValidPm25Trips(TripId, Pm25, Span) AS (
  SELECT TripId, Pm25, unnest(spans(whenTrue(Pm25 #> 150)))
  FROM Trips
  WHERE tfloat(Weather, 'Temperature', 'step') %> 25 AND 
    whenTrue(Pm25 #> 150) IS NOT NULL )
SELECT TripId, array_agg(Span) FILTER (WHERE Duration(Span) > '10 minutes')
FROM ValidPm25Trips
WHERE Duration(Span) > '10 minutes'
GROUP BY TripId
HAVING COUNT(*) > 1;

-- SELECT 4
-- Time: 177.354 ms

-------------------------------------------------------------------------------

SELECT DISTINCT tripid FROM tq5_34 EXCEPT SELECT DISTINCT tripid FROM q5_34 ORDER BY 1 LIMIT 5;
-- (0 rows)

SELECT DISTINCT tripid FROM q5_34 EXCEPT SELECT DISTINCT tripid FROM tq5_34 ORDER BY 1 LIMIT 5;
-- (0 rows)

-------------------------------------------------------------------------------
/*
Query 5.35. Trips such that there is at least a 30-minutes phase where
Pm25 was continuously higher than 300 in cloudy conditions, and
with Humidity higher than 80%.

[ (Pm25, @p), @p > '300', Duration(@p, @first) >= '30 minutes',
  (CloudCover, @cc), @cc > '0', (Humidity, @h), @h > '70']+
*/

-- NEW VERSION

DROP TABLE IF EXISTS Q5_35;
CREATE TABLE Q5_35 AS
WITH Segments AS (
  SELECT TripId, T, PM25, (Weather->>'CloudCover')::numeric AS CloudCover,
    (Weather->>'Humidity')::numeric AS Humidity,
    CASE
      WHEN PM25 > 300 AND (Weather->>'CloudCover')::numeric > 0 AND
        (Weather->>'Humidity')::numeric > 80
      THEN 1 ELSE 0
    END AS Valid
  FROM TripPoints ),
SegmentsPrev AS (
  SELECT *, LAG(Valid) OVER (PARTITION BY TripId ORDER BY T) AS PrevValid
  FROM Segments ),
Phases AS (
  SELECT *, SUM(CASE WHEN Valid = PrevValid THEN 0 ELSE 1 END) OVER
    (PARTITION BY TripId ORDER BY T) AS PhaseId
  FROM SegmentsPrev )
SELECT TripId, PhaseId, MIN(T) AS StartTime, MAX(T) AS EndTime,
  EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0 AS DurationMinutes,
  array_agg(PM25 ORDER BY T) AS Pm25Seq,
  array_agg(CloudCover ORDER BY T) AS CloudCoverSeq,
  array_agg(Humidity ORDER BY T) AS HumiditySeq
FROM Phases
GROUP BY TripId, PhaseId
HAVING EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0  >= 30 AND
  BOOL_AND(Valid = 1)
ORDER BY TripId, StartTime;

-- SELECT 71
-- Time: 66591.925 ms (01:06.592)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_35;
CREATE TABLE TQ5_35 AS
WITH SelectedTripsTime(TripId, Time) AS (
  SELECT TripId, unnest(spans(whenTrue(Pm25 #> 300) * 
    whenTrue(tfloat(Weather, 'CloudCover', 'step') #> 0) * 
    whenTrue(tfloat(Weather, 'Humidity', 'step') #> 80)))
  FROM Trips
  WHERE whenTrue(Pm25 #> 300) IS NOT NULL AND
    whenTrue(tfloat(Weather, 'CloudCover', 'step') #> 0) IS NOT NULL AND
    whenTrue(tfloat(Weather, 'Humidity', 'step') #> 80) IS NOT NULL )
SELECT d.TripId, atTime(d.Pm25, t.Time) AS Pm25, t.Time, 
  duration(t.time) AS Duration
FROM Trips d, SelectedTripsTime t
WHERE d.TripId = t.TripId AND duration(Time) >= '30 minutes'
ORDER BY TripId, Time;

-- SELECT 71
-- Time: 858.910 ms

-------------------------------------------------------------------------------

SELECT DISTINCT tripid FROM tq5_35 EXCEPT SELECT DISTINCT tripid FROM q5_35 ORDER BY 1 LIMIT 5;
-- (0 rows)

SELECT DISTINCT tripid FROM q5_35 EXCEPT SELECT DISTINCT tripid FROM tq5_35 ORDER BY 1 LIMIT 5;
-- (0 rows)

-------------------------------------------------------------------------------

