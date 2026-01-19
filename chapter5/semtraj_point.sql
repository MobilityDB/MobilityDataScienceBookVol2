
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
WITH TripPm25(TripId, T, Pm25, PrevPm25) AS (
  SELECT TripId, T, Pm25, LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPoints ),
TripsIncPm25(TripId) AS (
  SELECT TripId
  FROM TripPm25
  WHERE PrevPm25 IS NOT NULL
  GROUP BY TripId
  HAVING bool_and(Pm25 > PrevPm25) )
SELECT p.TripId, MIN(p.T) AS StartTime, MAX(p.T) AS EndTime,
  array_agg(p.Pm25 ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, TripsIncPm25 i
WHERE p.TripId = i.TripId
GROUP BY p.TripId
ORDER BY TripId, StartTime;

-- SELECT 708
-- Time: 8853.652 ms (00:08.854)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_29;
CREATE TABLE TQ5_29 AS
WITH Segments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips
  WHERE numInstants(Pm2_5) > 1 )
SELECT TripId, DeviceId, Pm2_5
FROM DelhiTrips
WHERE numInstants(Pm2_5) > 1 AND tripId NOT IN (
  SELECT DISTINCT TripId
  FROM Segments
  WHERE startValue(Segm) > endValue(Segm) );

-- SELECT 1001
-- Time: 2622.876 ms (00:02.623)

------------------------------------------------------------------------------

/*
Query 5.30. Trips have at least a continuous run of 10 minutes with strictly
increasing Pm25, followed by a continuous run of strictly decreasing Pm25.


[ (Pm25, @p), prev(Pm25) < @p, Duration(@p, @first) >= '10 minutes' ]+.*
[ (Pm25, @q), prev(Pm25) > @q ]
I+.D+
*/

-- DROP TABLE IF EXISTS Q5_30;
-- CREATE TABLE Q5_30 AS
WITH TripPm25(TripId, T, Pm25, Trend) AS (
  SELECT TripId, T, Pm25,
    CASE
      WHEN Pm25 >= LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) THEN 1
      WHEN Pm25 < LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T) THEN -1
      ELSE 0
    END
  FROM TripPoints ),
-- Compute previous trend for run identification
Runs(TripId, T, Pm25, Trend, PrevTrend) AS (
  SELECT *, LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25
  WHERE Trend <> 0 ),
-- Assign run Ids
RunIds(TripId, RunId, T, Pm25, Trend, PrevTrend) AS (
  SELECT TripId, SUM(CASE WHEN Trend = PrevTrend THEN 0 ELSE 1 END)
    OVER (PARTITION BY TripId ORDER BY T), T, Pm25, Trend, PrevTrend
  FROM Runs ),
-- Compute run start and end timestamps and duration
RunTimes(TripId, RunId, Trend, StartTime, EndTime, Duration) AS (
  SELECT TripId, RunId, Trend, MIN(T), MAX(T),
    EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0
  FROM RunIds
  GROUP BY TripId, RunId, Trend
  HAVING EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0 >= 1.5 ),
-- Get Pm25 at start and end of each run
RunBounds(TripId, RunId, Trend, StartTime, EndTime, Duration, StartPm25,
    EndPm25) AS (
  SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime,  r.Duration,
    s.Pm25, e.Pm25
  FROM RunTimes r, RunIds s, RunIds e
  WHERE s.TripId = r.TripId AND s.RunId = r.RunId AND s.T = r.StartTime AND 
    e.TripId = r.TripId AND e.RunId = r.RunId AND e.T = r.EndTime ),
-- Find increasing runs immediately followed by decreasing Runs
SelectedRuns(TripId, IncRun, DecRun) AS (
  SELECT r1.TripId, r1.RunId, r2.RunId
  FROM RunBounds r1, RunBounds r2
  WHERE r1.TripId = r2.TripId AND r1.RunId + 1 = r2.RunId AND r1.Trend = 1 AND
    r2.Trend = -1 )
SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime, r.Duration,
  r.StartPm25, r.EndPm25
FROM RunBounds r, SelectedRuns s
WHERE r.TripId = s.TripId AND r.RunId IN (s.IncRun, s.DecRun)
ORDER BY r.TripId, r.RunId;

-- (42 rows)
-- Time: 44571.900 ms (00:44.572)

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TQ5_30;
CREATE TABLE TQ5_30 AS
WITH TripSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Pm2_5))
  FROM DelhiTrips ),
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
  GROUP BY TripId ),
TrendSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Trend))
  FROM TripTrend ),
TripSegmLabel(TripId, Label, T) AS (
  SELECT TripId,
    CASE
      WHEN startValue(Segm) = 'I' AND duration(Segm) > '5 min' THEN 'A'
      WHEN startValue(Segm) = 'D' THEN 'B'
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

-------------------------------------------------------------------------------

/*
5.32. Trips where the Pm25 strictly increases continuously for at least
5 minutes, always with of values of Pm25 higher than 125, followed by a
strictly continuous decrease of at least 2 minutes, and such that in both
runs, the temperature was always higher than 20 degrees.

[(Pm25, @p), prev(Pm25) < @p, @p > '125', Duration(@p, @first) >= '5 minutes', (Temp, @tp), @tp > '20']+.
[(Pm25, @q), prev(Pm25) > @q, Duration(@q, @first2) >= '2 minutes', (Temp, @tq), @tq > '20']+
*/

-- DROP TABLE IF EXISTS Q5_32;
-- CREATE TABLE Q5_32 AS
WITH TripPm25Temp(TripId, T, Pm25, Temp, Trend) AS (
  SELECT TripId, T, (Attributes->>'Pm25')::numeric,
    (Attributes->>'Temperature')::numeric,
    CASE
      WHEN (Attributes->>'Pm25')::numeric > LAG((Attributes->>'Pm25')::numeric)
        OVER (PARTITION BY TripId ORDER BY T) THEN 1
      WHEN (Attributes->>'Pm25')::numeric < LAG((Attributes->>'Pm25')::numeric)
        OVER (PARTITION BY TripId ORDER BY T) THEN -1
      ELSE 0
    END
    FROM TripPoints
    WHERE (Attributes->>'Pm25')::numeric > 125 AND
      (Attributes->>'Temperature')::numeric > 20 ),
-- Compute previous trend for run identification
Runs(TripId, T, Pm25, Temp, Trend, PrevTrend) AS (
  SELECT *, LAG(Trend) OVER (PARTITION BY TripId ORDER BY T)
  FROM TripPm25Temp
  WHERE Trend <> 0 ),
-- Assign run Ids
RunIds(TripId, T, Pm25, Temp, Trend, PrevTrend, RunId) AS (
  SELECT *, SUM(CASE WHEN Trend = PrevTrend THEN 0 ELSE 1 END)
    OVER (PARTITION BY TripId ORDER BY T)
  FROM Runs ),
-- Compute run start/end timestamps and Duration
RunTimes(TripId, RunId, Trend, StartTime, EndTime, Duration) AS (
  SELECT TripId, RunId, Trend, MIN(T), MAX(T),
    EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0
  FROM RunIds
  GROUP BY TripId, RunId, Trend ),
-- Keep only runs that satisfy Duration constraints
SelectedRuns AS (
  SELECT *
  FROM RunTimes
  WHERE (Trend = 1 AND Duration >= 5) OR (Trend = -1 AND Duration >= 2) ),
-- Get Pm25 and temperature sequences for each run
RunBounds(TripId, RunId, Trend, StartTime, EndTime, Duration, Pm25Seq,
    TempSeq) AS (
  SELECT s.TripId, s.RunId, s.Trend, s.StartTime, s.EndTime, s.Duration,
    array_agg((p.Attributes->>'Pm25')::numeric ORDER BY p.T),
    array_agg((p.Attributes->>'Temperature')::numeric ORDER BY p.T) 
  FROM SelectedRuns s, TripPoints p
  WHERE p.TripId = s.TripId AND p.T >= s.StartTime AND p.T <= s.EndTime
  GROUP BY s.TripId, s.RunId, s.Trend, s.StartTime, s.EndTime, s.Duration ),
-- Find increasing runs immediately followed by decreasing runs
IncDecPairs(TripId, IncRun, DecRun) AS (
  SELECT r1.TripId, r1.RunId, r2.RunId
  FROM RunBounds r1, RunBounds r2
  WHERE r1.TripId = r2.TripId AND r1.RunId + 1 = r2.RunId AND
    r1.Trend = 1 AND r2.Trend = -1 )
SELECT r.TripId, r.RunId, r.Trend, r.StartTime, r.EndTime,
  r.Duration, r.Pm25Seq, r.TempSeq
FROM RunBounds r, IncDecPairs p
WHERE r.TripId = p.TripId AND r.RunId IN (p.IncRun, p.DecRun)
ORDER BY r.TripId, r.RunId;

-- (22 rows)
-- Time: 7465.085 ms (00:07.465)

/*
5.32. Trips where the Pm25 strictly increases continuously for at least
5 minutes, always with of values of Pm25 higher than 125, followed by a
strictly continuous decrease of at least 2 minutes, and such that in both
runs, the temperature was always higher than 20 degrees.

[(Pm25, @p), prev(Pm25) < @p, @p > '125', Duration(@p, @first) >= '5 minutes', (Temp, @tp), @tp > '20']+.
[(Pm25, @q), prev(Pm25) > @q, Duration(@q, @first2) >= '2 minutes', (Temp, @tq), @tq > '20']+
*/

-- TEMPORAL VERSION

-- DROP TABLE IF EXISTS TQ5_32;
-- CREATE TABLE TQ5_32 AS
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
      WHEN startValue(Segm) = 'D' THEN 'B'
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

-------------------------------------------------------------------------------

/*
Query 5.35. Trips that started FROM a Pm25 lower than 130 and at some
point reached a value higher than 180.

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

-- (1336 rows)
-- Time: 8170.872 ms (00:08.171)

-------------------------------------------------------------------------------

/*
Query 5.36. Same as Query 5.35, but such that the elapsed time between
the increase of values in less than thirty minutes.

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

-- (1087 rows)
-- Time: 6429.412 ms (00:06.429)

-------------------------------------------------------------------------------

/*
Query 5.37. Trips traveling all their way under a temperature higher
than 20 degrees and such that at in at least any two Runs longer than
2 minutes, the Pm25 was higher than 150.

[ (Pm25, @p1), @p1 > '150', Duration(@p1, @first1) > '2 minutes', (Temp, @t1), @t1 > '20' ]+ .
[ (Pm25, @p2), @p2 > '150', Duration(@p2, @first2) > '2 minutes', (Temp, @t2), @t2 > '20' ]+
*/

-- Only consider points where temperature > 20
WITH Filtered(TripId, T, Pm25, Temp, HighPm) AS (
  SELECT TripId, T, (Attributes->>'Pm25')::numeric,
    (Attributes->>'Temperature')::numeric,
    CASE WHEN (Attributes->>'Pm25')::numeric > 150 THEN 1 ELSE 0 END
  FROM TripPoints
  WHERE (Attributes->>'Temperature')::numeric > 20 ),
-- Assign run Ids to consecutive HighPm points using gaps-and-islands
Runs(TripId, T, Pm25, Temp, HighPm, RunId) AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY T) -
    ROW_NUMBER() OVER (PARTITION BY TripId, HighPm ORDER BY T)
  FROM Filtered ),
-- Compute start, end, and duration of each run
RunTimes(TripId, HighPm, RunId, StartTime, EndTime, Duration, Pm25Seq,
    TempSeq) AS (
  SELECT TripId, HighPm, RunId, MIN(T), MAX(T),
    EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0,
    array_agg(Pm25 ORDER BY T), array_agg(Temp ORDER BY T)
  FROM Runs
  GROUP BY TripId, HighPm, RunId ),
-- Keep only HighPm Runs longer than 2 minutes
SelectedRuns AS (
  SELECT *
  FROM RunTimes
  WHERE HighPm = 1 AND Duration > 2 ),
-- Count number of qualifying Runs per trip
TripCounts(TripId, NumRuns) AS (
  SELECT TripId, COUNT(*)
  FROM SelectedRuns
  GROUP BY TripId
  HAVING COUNT(*) >= 2 )
SELECT s.TripId, s.RunId, s.StartTime, s.EndTime, s.Duration, s.Pm25Seq,
  s.TempSeq
FROM SelectedRuns s, TripCounts c
WHERE s.TripId = c.TripId
ORDER BY s.TripId, s.StartTime;

-- (870 rows)
-- Time: 5392.915 ms (00:05.393)

-------------------------------------------------------------------------------
/*
Query 5.38. Trips such that there is at least a 20-minutes run where
Pm25 was continuously higher than 150  in cloudy conditions, and
with Humidity higher than 70%.

[ (Pm25, @p), @p > '150', Duration(@p, @first) >= '20 minutes',
  (CloudCover, @cc), @cc > '0', (Humidity, @h), @h > '70']+
*/

-- Only consider points satisfying all conditions
WITH Filtered(TripId, T, Pm25, CloudCover, Humidity) AS (
  SELECT TripId, T, (Attributes->>'Pm25')::numeric,
    (Attributes->>'CloudCover')::numeric, (Attributes->>'Humidity')::numeric
  FROM TripPoints
  WHERE (Attributes->>'Pm25')::numeric > 150 AND
    (Attributes->>'CloudCover')::numeric > 0 AND
    (Attributes->>'Humidity')::numeric > 70 ),
-- Assign run Ids to consecutive points using gaps-and-islands
Runs(TripId, T, Pm25, CloudCover, Humidity, RunId) AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY T) -
    ROW_NUMBER() OVER (PARTITION BY TripId, TripId ORDER BY T)
  FROM Filtered ),
-- Compute run start, end, duration, and sequences
RunTimes(TripId, RunId, StartTime, EndTime, Duration, Pm25Seq, CloudCoverSeq,
  HumiditySeq) AS (
SELECT TripId, RunId, MIN(T), MAX(T),
  EXTRACT(EPOCH FROM MAX(T) - MIN(T)) / 60.0,
  array_agg(Pm25 ORDER BY T), array_agg(CloudCover ORDER BY T),
  array_agg(Humidity ORDER BY T)
  FROM Runs
  GROUP BY TripId, RunId )
-- Keep only runs lasting at least 20 minutes
SELECT *
FROM RunTimes
WHERE Duration >= 20
ORDER BY TripId, StartTime;

-- (553 rows)
-- Time: 4330.324 ms (00:04.330)

-------------------------------------------------------------------------------
