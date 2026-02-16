-------------------------------------------------------------------------------
/*
Query 5.29. Trajectories that continuously traverse cells with increasing Pm25 values.
*/

-- Compute the change in Pm25 between consecutive sections of the same trip
WITH Deltas(TripId, CellId, Weather, Pm25, Delta) AS (
  SELECT TripId, CellId, Weather, Pm25,
    Pm25 - LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM TripCells ),
-- Select only those trips whose Pm25 is strictly increasing throughout
SelectedTrips(TripId) AS (
  SELECT TripId 
  FROM Deltas
  GROUP BY TripId 
  HAVING COUNT(*) >= 2 AND COUNT(*) FILTER (WHERE Delta <= 0) = 0 )
SELECT TripId, array_agg(ROW(CellId, ROUND(Pm25::numeric, 2))
  ORDER BY StartTime) AS Pm25Seq
FROM TripCells
WHERE TripId IN (SELECT TripId FROM SelectedTrips)
GROUP BY TripId
ORDER BY TripId;

-- 1102 rows
-- Time: 138.142 ms

-------------------------------------------------------------------------------
/*
Query 5.30. Trajectories that have at least two continuous strictly increasing
sections of Pm25, followed by at least two continuously strictly decreasing sections.
*/

-- DROP TABLE IF EXISTS GQ5_30;
-- CREATE TABLE GQ5_30 AS
WITH Trends(TripId, CellId, StartTime, EndTime, Pm25, Trend) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    SIGN((LEAD(Pm25) OVER w) - Pm25) /* Compute the trend */
  FROM TripCells
  WINDOW w AS (PARTITION BY TripId ORDER BY StartTime) ),
PhaseStarts(TripId, CellId, StartTime, EndTime, Pm25, Trend, NewPhase) AS (
  SELECT *,
    CASE
      WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY
        StartTime) THEN 0 ELSE 1
    END
  FROM Trends
  WHERE Trend <> 0 ),
Phases(TripId, PhaseId, CellId, StartTime, EndTime, Pm25, Trend) AS (
  SELECT TripId, SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY
    StartTime), CellId, StartTime, EndTime, Pm25, Trend
  FROM PhaseStarts ),
PhaseLengths(TripId, PhaseId, Trend, Length) AS (
  SELECT TripId, PhaseId, Trend, COUNT(*)
  FROM Phases
  GROUP BY TripId, PhaseId, Trend ),
PhasePairs(TripId, IncrPhase, DecrPhase) AS (
  SELECT p1.TripId, p1.PhaseId, p2.PhaseId
  FROM PhaseLengths p1, PhaseLengths p2
  WHERE p2.TripId = p1.TripId AND p2.PhaseId = p1.PhaseId + 1 AND
    p1.Trend =  1 AND p1.Length >= 2 AND p2.Trend = -1 AND p2.Length >= 2 )
SELECT r.TripId, array_agg(ROW(r.CellId, ROUND(r.Pm25::numeric, 2),
  CASE 
    WHEN r.PhaseId = s.IncrPhase THEN 'I'
    WHEN r.PhaseId = s.DecrPhase THEN 'D'
  END) ORDER BY r.StartTime) AS Pm25Seq
FROM Phases r, PhasePairs s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncrPhase, s.DecrPhase)
GROUP BY r.TripId
ORDER BY r.TripId;

-- 1135 rows
-- Time: 334.852 ms

-------------------------------------------------------------------------------
/*
Query 5.31 Trajectories that have at least K (K >=2) continuous strictly
increasing sections of Pm25, followed by M (M>=2) continuously strictly
decreasing sections.
*/

-- Minimum increasing and decreasing sections
WITH Params(K, M) AS ( SELECT 2, 3 ),
Trends(TripId, CellId, StartTime, EndTime, Pm25, Trend) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    SIGN((LEAD(Pm25) OVER w) - Pm25) /* Compute the trend */
  FROM TripCells
  WINDOW w AS (PARTITION BY TripId ORDER BY StartTime) ),
Phases(TripId, PhaseId, CellId, StartTime, EndTime, Pm25, Trend) AS (
  SELECT TripId, SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY
    StartTime), CellId, StartTime, EndTime, Pm25, Trend
  FROM (
    SELECT *,
      CASE
        WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY
          StartTime) THEN 0 ELSE 1
      END AS NewPhase
      FROM Trends
      WHERE Trend <> 0 ) AS Temp ),
PhaseLengths(TripId, PhaseId, Trend, Length) AS (
  SELECT TripId, PhaseId, Trend, COUNT(*)
  FROM Phases
  GROUP BY TripId, PhaseId, Trend ),s
SelectedPhasePairs AS (
  SELECT p1.TripId, p1.PhaseId AS IncrPhase, p2.PhaseId AS DecrPhase
  FROM PhaseLengths p1, PhaseLengths p2, Params p 
  WHERE p1.TripId = p2.TripId AND p2.PhaseId = p1.PhaseId + 1 AND 
    p1.Trend = 1 AND p1.Length >= p.K AND p2.Trend = -1 AND p2.Length >= p.M )
SELECT r.TripId, array_agg(ROW(r.CellId, ROUND(r.Pm25::numeric, 2),
  CASE
    WHEN r.PhaseId = s.IncrPhase THEN 'I'
    WHEN r.PhaseId = s.DecrPhase THEN 'D'
  END) ORDER BY r.StartTime) AS Sequence
FROM Phases r, SelectedPhasePairs s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncrPhase, s.DecrPhase)
GROUP BY r.TripId
ORDER BY r.TripId;

-- 594 rows
-- Time: 283.175 ms

-------------------------------------------------------------------------------
/*
5.32 Trajectories that have at least three continuously increasing sections
with values Pm25 higher than 125, followed by two continuously decreasing
sections and such that in these sections the temperature was always higher
than 20 degrees.
*/

-- SHOULD START WITH THIS
WITH Trends(TripId, CellId, StartTime, EndTime, Pm25, Weather, Trend) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Weather,
    SIGN((LEAD(Pm25) OVER w) - Pm25) /* Compute the trend */
  FROM TripCells
  WINDOW w AS (PARTITION BY TripId ORDER BY StartTime) ),

WITH TripsOrdered(TripId, CellId, StartTime, EndTime, Pm25, Weather, PrevPm25) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Weather,
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM TripCells ),
Trends(TripId, CellId, StartTime, EndTime, Pm25, Weather, Trend) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Weather,
    CASE
      WHEN Pm25 > PrevPm25 THEN 1 WHEN Pm25 < PrevPm25 THEN -1 ELSE 0
    END
  FROM TripsOrdered ),
PhaseStarts(TripId, CellId, StartTime, EndTime, Pm25, Weather, Trend, NewPhase) AS (
  SELECT *,
    CASE
      WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY StartTime)
        THEN 0 ELSE 1
    END
  FROM Trends
  WHERE Trend <> 0 ),
-- Assign a PhaseId to maximal contiguous segments with the same monotonic trend
Phases(TripId, PhaseId, CellId, StartTime, EndTime, Pm25, Weather, Trend) AS (
  SELECT TripId, SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY StartTime),
    CellId, StartTime, EndTime, Pm25, Weather, Trend
  FROM PhaseStarts ),
-- Compute phase lengths and validates Pm25 and temperature constraints per phase
PhaseLenghts AS (
  SELECT TripId, PhaseId, Trend, COUNT(*) AS PhaseLen,
    bool_and(Pm25 > 125) FILTER (WHERE Trend = 1) AS IncrPm25,
    bool_and((Weather->>'Temperature')::numeric > 20) FILTER
      (WHERE Trend = -1) AS DecrTemp
  FROM Phases
  GROUP BY TripId, PhaseId, Trend ),
-- Select adjacent increasing/decreasing phases that satisfy length and value conditions
PhasePairs AS (
  SELECT p1.TripId, p1.PhaseId AS IncrPhase, p2.PhaseId AS DecrPhase
  FROM PhaseLenghts p1, PhaseLenghts p2
  WHERE p2.TripId = p1.TripId AND p2.PhaseId = p1.PhaseId + 1 AND
    p1.Trend = 1 AND p1.PhaseLen >= 3 AND p1.IncrPm25 AND p2.Trend = -1 AND
    p2.PhaseLen >= 2 AND p2.DecrTemp )
-- Return every section (CellId) participating in a valid pattern.
SELECT r.TripId, array_agg(ROW(r.CellId, ROUND(r.Pm25::numeric, 2),
  (r.Weather->>'Temperature')::numeric,
  CASE
    WHEN r.PhaseId = s.IncrPhase THEN 'I'
    WHEN r.PhaseId = s.DecrPhase THEN 'D'
  END) ORDER BY r.StartTime) AS Sequence
FROM Phases r, PhasePairs s
WHERE s.TripId = r.TripId AND r.PhaseId IN (s.IncrPhase, s.DecrPhase)
GROUP BY r.TripId
ORDER BY r.TripId;

-- 67 rows

-------------------------------------------------------------------------------
/*
Query 5.33. Trips that traversed at least twice the same cell with exactly
one different cell in between.
*/

-- Order each trip by time and expose the previous two cells
WITH Ordered(TripId, CellId, StartTime, Prev2Cell, PrevCell) AS (
  SELECT TripId, CellId, StartTime, LAG(CellId, 2) OVER w, 
    LAG(CellId, 1) OVER w
  FROM TripCells
  WINDOW w AS (PARTITION BY TripId ORDER BY StartTime) )
SELECT TripId, array_agg(ROW(Prev2Cell, PrevCell, CellId, StartTime)
  ORDER BY StartTime) AS Patterns
FROM Ordered
WHERE Prev2Cell IS NOT NULL AND CellId = Prev2Cell AND PrevCell <> CellId
GROUP BY TripId
ORDER BY TripId;

-- 2213 rows
-------------------------------------------------------------------------------
/*
Query 5.34. Trips that traversed at least twice the same cell with exactly
two different cells in between. In this case we are asking for patterns like
A -> B -> C -> A, with the following constraints:
• The first and last cells are the same
• There are exactly two cells in between, such the two middle cells are both
different, that is B <> C, B <> A, C <> A
*/

-- Order each trip and expose the three previous visited cells
WITH Ordered(TripId, CellId, StartTime, Prev3Cell, Prev2Cell, PrevCell) AS (
  SELECT TripId, CellId, StartTime,
    LAG(CellId, 3) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(CellId, 2) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(CellId, 1) OVER (PARTITION BY TripId ORDER BY StartTime)
    FROM TripCells )
SELECT TripId, array_agg(ROW(Prev3Cell, Prev2Cell, PrevCell,CellId, StartTime) 
  ORDER BY StartTime) AS Patterns
FROM Ordered
WHERE Prev3Cell IS NOT NULL AND Prev2Cell IS NOT NULL AND PrevCell  IS NOT NULL
  AND CellId = Prev3Cell       -- A → B → C → A
  AND Prev2Cell <> PrevCell    -- B ≠ C
  AND Prev2Cell <> CellId      -- B ≠ A
  AND PrevCell  <> CellId      -- C ≠ A
GROUP BY TripId
ORDER BY TripId;

-- 63 rows

-------------------------------------------------------------------------------%%%%
/*
Query 5.35. Trips that started from a Pm25 lower   than 100 (
OR at some point dropped below 100) and at some
point reached a value higher than 400.
*/

-- Order each trip and expose the first Pm25 value
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, RowNo) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM TripCells),
-- Select trips whose first section starts with Pm25 < 100
-- and that later reaches Pm25 > 400
SelectedTrips AS (
  SELECT DISTINCT o1.TripId
  FROM Ordered o1, Ordered o2
  WHERE o1.TripId = o2.TripId AND o1.RowNo = 1 AND o1.Pm25 < 100
    AND o2.Pm25 > 400)
-- One row per trip, aggregate the selected sections
SELECT o.TripId, array_agg(ROW(o.RowNo, o.CellId, o.StartTime, o.EndTime,
  ROUND(o.Pm25::numeric, 2),
  CASE
    WHEN o.RowNo = 1 THEN 'start (<100)'
    WHEN o.Pm25 > 400 THEN 'exceeds 400'
  END) ORDER BY o.StartTime) AS Sections
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId AND (o.RowNo = 1 OR o.Pm25 > 400)
GROUP BY o.TripId
ORDER BY o.TripId;

-- 5 rows
-------------------------------------------------------------------------------
/*
Query 5.36. Same as Query 5.35, but such that the elapsed time between
the increase of values is less than five minutes.
*/

-- Order each trip and assign a sequence number to each section
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, RowNo) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM TripCells ),
-- Identify the starting section of each trip with Pm25 < 130
Starts AS (
  SELECT TripId, CellId AS StartCell, StartTime, Pm25 AS StartPm25
  FROM Ordered
  WHERE RowNo = 1 AND Pm25 < 100 ),
-- Find for each trip the first section where Pm25 exceeds 180
FirstExceed AS (
  SELECT DISTINCT ON (TripId) TripId, CellId AS ExceedCell,
    StartTime AS ExceedTime, Pm25 AS ExceedPm25
  FROM Ordered
  WHERE Pm25 > 400
  ORDER BY TripId, StartTime ),
-- Keep only trips where the increase happens within 5 minutes
SelectedTrips(TripId, StartTime, ExceedTime, ElapsedTime) AS (
  SELECT s.TripId, s.StartTime, f.ExceedTime, (f.ExceedTime - s.StartTime)
  FROM Starts s, FirstExceed f
  WHERE f.TripId = s.TripId AND
    f.ExceedTime - s.StartTime < interval '5 minutes' )
-- Show the concrete sections satisfying the pattern with elapsed time
SELECT o.TripId, s.ElapsedTime,
  array_agg(ROW(o.CellId, o.StartTime, o.EndTime, ROUND(o.Pm25::numeric, 2),
      CASE
        WHEN o.StartTime = s.StartTime THEN 'start (<100)'
        WHEN o.StartTime = s.ExceedTime THEN 'first (>400)'
        ELSE 'intermediate'
      END) ORDER BY o.StartTime) AS Sections
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId
  AND o.StartTime BETWEEN s.StartTime AND s.ExceedTime
GROUP BY o.TripId, s.ElapsedTime
ORDER BY o.TripId;
-- 2 rows

-------------------------------------------------------------------------------
/*
Query 5.37. Trips traveling all their way under a Temperature higher
than 20 degrees and such that at in at least any two consecutive sections,
the Pm25 was higher than 150.
*/

-- Order each trip and expose the previous section values
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, Weather,
  PrevCellId, PrevStartTime, PrevPm25, PrevAttributes) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Weather,
    LAG(CellId) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(StartTime) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(Weather) OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM TripCells ),
-- Keep only trips where ALL sections have temperature > 20
SelectedTrips AS (
  SELECT TripId
  FROM TripCells
  GROUP BY TripId
  HAVING bool_and((Weather->>'Temperature')::numeric > 20) )
-- Return the concrete consecutive sections satisfying the condition
SELECT o.TripId,
  array_agg(
    ROW(
      -- first section
      o.PrevCellId, o.PrevStartTime, ROUND(o.PrevPm25::numeric, 2),
      (o.PrevAttributes->>'Temperature')::numeric,
      -- second section
      o.CellId, o.StartTime, ROUND(o.Pm25::numeric, 2),
      (o.Weather->>'Temperature')::numeric)
    ORDER BY o.PrevStartTime) AS SectionPairs
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId
  AND o.PrevPm25 > 150
  AND o.Pm25 > 150
GROUP BY o.TripId
ORDER BY o.TripId;

-- 1035 rows

-------------------------------------------------------------------------------
/*
Query 5.38. Trips that traversed at least three consecutive sections under
cloudy conditions (CloudCover > 0) with Pm25 higher than 300 and with humidity higher
than 80.
*/

-- Order each trip and extract the relevant variables
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, Humidity, CloudCover,
    Rain) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    (Weather->>'Humidity')::numeric, (Weather->>'CloudCover')::numeric,
    (Weather->>'Rain')::numeric
  FROM TripCells ),
-- Mark sections that satisfy all per-section constraints
Selected AS (
  SELECT *,
    CASE
      WHEN Pm25 > 300 AND Humidity > 80 AND CloudCover > 0 THEN 1 ELSE 0
    END AS Valid
    FROM Ordered ),
Phases AS (
  -- Assigns a PhaseId to consecutive sections satisfying the constraints.
  SELECT *,
    SUM(NewPhase) OVER (PARTITION BY TripId ORDER BY StartTime ) AS PhaseId
  FROM (
    SELECT *,
      CASE
        WHEN Valid = 1 AND LAG(Valid) OVER (PARTITION BY TripId ORDER BY
          StartTime) = 1 THEN 0 ELSE 1
      END AS NewPhase
    FROM Selected ) AS Temp ),
-- Compute the length of each selected phase
PhaseLenghts AS (
  SELECT TripId, PhaseId, COUNT(*) AS PhaseLen
  FROM Phases
  WHERE Valid = 1
  GROUP BY TripId, PhaseId
  HAVING COUNT(*) >= 3 )
-- Return the concrete sections belonging to the selected phases
SELECT r.TripId,
  array_agg(
    ROW(r.CellId, r.StartTime, r.EndTime, ROUND(r.Pm25::numeric, 2), r.Humidity,
      r.CloudCover, r.Rain) ORDER BY r.StartTime) AS PhaseSections
FROM Phases r, PhaseLenghts s
WHERE s.TripId = r.TripId AND s.PhaseId  = r.PhaseId AND r.Valid = 1
GROUP BY r.TripId
ORDER BY r.TripId; 

-- 87 rows

-----------------------------