/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- Exercises of the chapter Semantic Trajectories, run on the database built by
-- build.sh. Each query is the one the book prints in the answer of the exercise.
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Exercise 6.2, query 1
SELECT DISTINCT m.TourId, m.StepNo AS MuseumStep, m.PoI->>'Name' AS Museum,
  r.StepNo AS RestStep, r.PoI->>'Name' AS Restaurant
FROM TourPoI m JOIN TourPoI r ON r.TourId = m.TourId AND m.AtTime <<# r.AtTime
WHERE m.PoI->>'Category' = 'Museum' AND r.PoI->>'TypeOfFood' = 'Italian'
ORDER BY m.TourId, MuseumStep, RestStep;

\echo == Exercise 6.2, query 2
SELECT TourId, SUM(upper(AtTime) - lower(AtTime)) AS RestaurantTime
FROM TourPoI
WHERE PoI->>'Category' = 'Restaurant'
GROUP BY TourId ORDER BY RestaurantTime DESC, TourId;

\echo == Exercise 6.2, query 3
SELECT TourId,
  duration(getTime(atValue(Tour->>'Category', text 'Restaurant'))) AS RestaurantTime
FROM TempTour
WHERE atValue(Tour->>'Category', text 'Restaurant') IS NOT NULL
ORDER BY RestaurantTime DESC, TourId;

\echo == Exercise 6.3, query 1
SELECT TripId
FROM TripCellsSeq s
WHERE EXISTS (
  SELECT 1 FROM generate_subscripts(s.CellSeq, 1) AS i
  WHERE s.CellSeq[i] = 64 AND s.CellSeq[i + 1] = 63 )
ORDER BY TripId;

SELECT TripId
FROM TripCellsSeq s
WHERE array_position(s.CellSeq, 64) < array_position(s.CellSeq, 63)
ORDER BY TripId;

\echo == Exercise 6.4, query 1
SELECT TourId, MAX((PoI->>'Stars')::int) AS Stars,
  SUM(upper(AtTime) - lower(AtTime)) AS HotelTime
FROM TourPoI
WHERE PoI ? 'Stars'
GROUP BY TourId ORDER BY TourId;

\echo == Exercise 6.4, query 2
SELECT TourId,
  maxValue(tfloat(atTime(Tour, whenTrue(Tour ? 'Stars')), 'Stars', 'step')) AS Stars,
  duration(whenTrue(Tour ? 'Stars')) AS HotelTime
FROM TempTour
WHERE whenTrue(Tour ? 'Stars') IS NOT NULL
ORDER BY TourId;

\echo == Exercise 6.4, query 3
SELECT COUNT(*) AS Trips, SUM(duration(whenTrue(tfloat(Weather,
  'Temperature', 'step') #< 10))) AS ColdTime
FROM Trips
WHERE whenTrue(tfloat(Weather, 'Temperature', 'step') #< 10) IS NOT NULL;

\echo == Exercise 6.4, query 4
WITH Obs(TripId, T, Cold, NextT, NextCold) AS (
  SELECT TripId, T, (Weather->>'Temperature')::float < 10,
    LEAD(T) OVER w, LEAD((Weather->>'Temperature')::float < 10) OVER w
  FROM TripPoints
  WINDOW w AS (PARTITION BY TripId ORDER BY T) )
SELECT COUNT(DISTINCT TripId) FILTER (WHERE Cold) AS Trips,
  COUNT(DISTINCT TripId) FILTER (WHERE Cold AND NextCold) AS TripsWithTime,
  SUM(NextT - T) FILTER (WHERE Cold AND NextCold) AS ColdTime
FROM Obs;

\echo == Exercise 6.5, query 1
WITH RECURSIVE Expanded(TripId, Pos, Val, NextPos) AS (
  SELECT s.TripId, u.Pos, u.Val, LEAD(u.Pos)
    OVER (PARTITION BY s.TripId, u.Val ORDER BY u.Pos)
  FROM TripCellsSeq s CROSS JOIN
    LATERAL unnest(s.CellSeq) WITH ORDINALITY AS u(Val, Pos) ),
Cycle(TripId, StartPos, EndPos) AS (
  SELECT TripId, Pos, NextPos FROM Expanded WHERE NextPos IS NOT NULL ),
Kept(TripId, StartPos, EndPos) AS (
  ( SELECT DISTINCT ON (TripId) TripId, StartPos, EndPos
    FROM Cycle ORDER BY TripId, StartPos )
  UNION ALL
  SELECT n.TripId, n.StartPos, n.EndPos
  FROM Kept k CROSS JOIN LATERAL (
    SELECT c.TripId, c.StartPos, c.EndPos FROM Cycle c
    WHERE c.TripId = k.TripId AND c.StartPos > k.EndPos
    ORDER BY c.StartPos LIMIT 1 ) n )
SELECT k.TripId, k.StartPos, k.EndPos, s.CellSeq[k.StartPos:k.EndPos] AS MatchSeq
FROM Kept k JOIN TripCellsSeq s USING (TripId)
WHERE k.TripId = 4
ORDER BY k.StartPos;

\echo == Exercise 6.6, query 1
WITH Flag(TripId, T, High, NewRun) AS (
  SELECT TripId, T, Pm25 > 300, CASE WHEN (Pm25 > 300) IS DISTINCT FROM
    (LAG(Pm25) OVER w > 300) THEN 1 ELSE 0 END
  FROM TripPoints WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Run(TripId, RunId, T, High) AS (
  SELECT TripId, SUM(NewRun) OVER (PARTITION BY TripId ORDER BY T), T, High
  FROM Flag ),
Episode(TripId, StartTime, EndTime) AS (
  SELECT TripId, MIN(T), MAX(T) FROM Run WHERE High GROUP BY TripId, RunId
  HAVING MAX(T) - MIN(T) >= interval '10 minutes' )
SELECT COUNT(*) AS Episodes, COUNT(DISTINCT TripId) AS Trips,
  SUM(EndTime - StartTime) AS Total FROM Episode;

\echo == Exercise 6.6, query 2
WITH Episode(TripId, Period) AS (
  SELECT TripId, unnest(spans(whenTrue(segmentMinDuration(atValue(
    Pm25 #> 300, true), interval '10 minutes', false))))
  FROM Trips WHERE whenTrue(Pm25 #> 300) IS NOT NULL )
SELECT COUNT(*) AS Episodes, COUNT(DISTINCT TripId) AS Trips,
  SUM(upper(Period) - lower(Period)) AS Total FROM Episode;

\echo == Exercise 6.7, query 1
SELECT StepNo, Name, StartTime, EndTime
FROM PointDistricts WHERE TripId = 4 ORDER BY StepNo;

SELECT Name, lower(Sp) AS EnterTime, upper(Sp) AS LeaveTime
FROM ( SELECT Name, unnest(spans(AtTime)) AS Sp
  FROM TripDistricts WHERE TripId = 4 ) AS s
ORDER BY EnterTime;

\echo == Exercise 6.8, query 1
WITH Stored(CellId, Visits, AvgPm25) AS (
  SELECT CellId, COUNT(*), AVG(Pm25) FROM TripCells
  WHERE TripId = 6 GROUP BY CellId ),
Formed(CellId, TwAvgPm25) AS (
  SELECT CellId, twAvg(Pm25) FROM TripTiles WHERE TripId = 6 )
SELECT CellId, Visits, round(AvgPm25::numeric, 2) AS AvgPm25,
  round(TwAvgPm25::numeric, 2) AS TwAvgPm25
FROM Stored JOIN Formed USING (CellId)
ORDER BY CellId;
