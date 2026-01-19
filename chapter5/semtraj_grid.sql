
DROP TABLE IF EXISTS Grid;
CREATE TABLE Grid(CellId integer PRIMARY KEY, Box stbox);
INSERT INTO Grid(CellId, Box)
  WITH MBR(Box) AS (
    SELECT extent(Geom::stbox)
    FROM DelhiInput )
  SELECT (rec).INDEX, (rec).Tile
  FROM ( SELECT spaceTiles(Box, 2500) AS rec FROM MBR );

-- INSERT 0 120
-- Time: 6340.230 ms (00:06.340)
 
CREATE INDEX Grid_quadtree_Idx ON Grid USING SPGIST(Box);

-- Time: 12.635 ms

DROP TABLE IF EXISTS TripPointsGrid;
CREATE TABLE TripPointsGrid(CellId, TripId, T, Pm25, Geom, Attributes) AS
SELECT g.CellId, p.TripId, p.T, p.Pm25, p.Geom, p.Attributes
FROM Grid g, TripPoints p
WHERE g.Box @> stbox(p.Geom);

-- SELECT 7087619
-- Time: 38155.626 ms (00:38.156)

CREATE INDEX TripPointsGrid_Geom_Quadtree_Idx ON TripPointsGrid USING SPGIST(Geom);

-- Time: 95626.378 ms (01:35.626)

CREATE INDEX TripPointsGrid_T_Idx ON TripPointsGrid(T); 

-- Time: 5421.290 ms (00:05.421)

/*
SELECT * FROM TripPointsGrid WHERE TripId=10 ORDER BY TripId, T, CellId limit 500; 
*/

DROP TABLE IF EXISTS GridCells;
CREATE TABLE GridCells(TripId, CellId, StartTime, EndTime, Pm25Min, Pm25Max, 
  Pm25, Attributes) AS
WITH SelectedCells(CellId, TripId, T, Pm25, Geom, Attributes, PrevCell) AS (
  SELECT *, LAG(CellId) OVER (PARTITION BY TripId ORDER BY T ) AS PrevCell
  FROM TripPointsGrid ),
Islands(CellId, TripId, T, Pm25, Geom, Attributes, PrevCell, NewGroup) AS (
  SELECT *,
    CASE 
      WHEN PrevCell IS NULL OR CellId <> PrevCell THEN 1 ELSE 0
    END
    FROM SelectedCells ),
Groups(CellId, TripId, T, Pm25, Geom, Attributes, PrevCell, NewGroup, Grp) AS (
  SELECT *, SUM(NewGroup) OVER (PARTITION BY TripId ORDER BY T
    ROWS UNBOUNDED PRECEDING)
  FROM Islands ),
IntervalStarts(TripId, CellId, Grp, StartTime, Pm25Min, Pm25Max, Pm25) AS (
  SELECT TripId, CellId, Grp, MIN(T), MIN(Pm25), MAX(Pm25), AVG(Pm25),
    -- Weather attributes encoded in JSONB
    jsonb_build_object(
      'Rain', AVG( (Attributes->>'Rain')::float),
      'Temperature', AVG( (Attributes->>'Temperature')::float),
      'Wind', AVG( (Attributes->>'Wind')::float),
      'Humidity', AVG( (Attributes->>'Humidity')::float),
      'CloudCover', AVG( (Attributes->>'CloudCover')::float)
    ) AS Attributes
    FROM Groups
    GROUP BY TripId, CellId, Grp ),
TripEnds(TripId, TripEnd) AS (
  SELECT TripId, MAX(T)
  FROM TripPointsGrid
  GROUP BY TripId )
SELECT i.TripId, i.CellId, i.StartTime,
  COALESCE(LEAD(i.StartTime) OVER (PARTITION BY i.TripId ORDER BY i.StartTime),
    e.TripEnd), i.Pm25Min, i.Pm25Max, i.Pm25, i.Attributes
FROM IntervalStarts i, TripEnds e
WHERE i.TripId = e.TripId
ORDER BY i.TripId, i.StartTime;

-- SELECT 70881
-- Time: 34820.179 ms (00:34.820)

CREATE INDEX TripId_Idx ON GridCells(TripId);

-- Time: 7304.970 ms (00:07.305)

CREATE INDEX CellId_Idx ON GridCells(CellId);

-- Time: 5545.341 ms (00:05.545)

-------------------------------------------------------------------------------

/* 
-- Para crear el intervalo semiabierto por si lo necesitamos

ALTER TABLE GridCells
ADD COLUMN TimeCellInterval tsrange
GENERATED ALWAYS AS (tsrange(StartTime,  EndTime, '[)')) STORED;
-- 10 secs

SELECT TripId, CellId, StartTime, EndTime, Pm25, Attributes, TimeCellInterval
FROM GridCells 
ORDER BY TripId, StartTime
LIMIT 100;
*/

-------------------------------------------------------------------------------
/*
Query 5.29. Trajectories that continuously traverse cells 
with increasing Pm25 values.
*/

-- Transform each trip into a time-ordered sequence of sections with Pm25 values
WITH SectionsWithTime(TripId, CellId, Attributes, Pm25, T) AS (
  SELECT TripId, CellId, Attributes, Pm25, StartTime
  FROM GridCells ),
-- Compute the change in Pm25 between consecutive sections of the same trip
Diffs(TripId, CellId, Pm25, Attributes, Delta) AS (
  SELECT TripId, CellId, Pm25, Attributes,
    Pm25 - LAG(Pm25) OVER (PARTITION BY TripId ORDER BY T)
  FROM SectionsWithTime ),
-- Select only those trips whose Pm25 is strictly increasing throughout
SelectedTrips(TripId) AS (
  SELECT TripId 
  FROM Diffs
  GROUP BY TripId 
  HAVING COUNT(*) >= 2 AND COUNT(*) FILTER (WHERE Delta <= 0) = 0 )
SELECT o.TripId, o.CellId, o.Pm25, o.Attributes
FROM SectionsWithTime o, SelectedTrips s
WHERE o.TripId = s.TripId
ORDER BY o.TripId, o.T;

-- (2525 rows)
-- Time: 169.812 ms

-------------------------------------------------------------------------------
/*
Query 5.30. Trajectories that have at least two continuous strictly increasing
sections of Pm25, followed by at least two continuously strictly decreasing sections.
*/

WITH Ordered AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime) AS PrevPm25
  FROM GridCells ),
Trend AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    CASE
      WHEN Pm25 > PrevPm25 THEN  1 WHEN Pm25 < PrevPm25 THEN -1 ELSE 0
    END AS Trend
  FROM Ordered ),
Runs AS (
  SELECT *, SUM(NewRun) OVER (PARTITION BY TripId ORDER BY StartTime) AS RunId
  FROM (
    SELECT *,
      CASE
        WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY StartTime)
          THEN 0 ELSE 1 END AS NewRun
    FROM Trend
    WHERE Trend <> 0 ) AS Temp ),
SelectedRunPairs AS (
  SELECT r1.TripId, r1.RunId AS IncRun, r2.RunId AS DecRun
  FROM (
      SELECT TripId, RunId, Trend, COUNT(*) AS len
      FROM Runs
      GROUP BY TripId, RunId, Trend ) r1
    JOIN (
      SELECT TripId, RunId, Trend, COUNT(*) AS len
      FROM Runs
      GROUP BY TripId, RunId, Trend ) r2
    ON r2.TripId = r1.TripId AND r2.RunId = r1.RunId + 1
    WHERE r1.Trend =  1 AND r1.len >= 2 AND r2.Trend = -1 AND r2.len >= 2 )
SELECT r.TripId, r.CellId, r.StartTime, r.EndTime, r.Pm25,
  CASE
    WHEN r.RunId = s.IncRun THEN 'increasing'
    WHEN r.RunId = s.DecRun THEN 'decreasing'
  END AS Phase
FROM Runs r, SelectedRunPairs s
WHERE s.TripId = r.TripId AND r.RunId IN (s.IncRun, s.DecRun)
ORDER BY r.TripId, r.StartTime;

-- (10302 rows)
-- Time: 312.343 ms

-------------------------------------------------------------------------------
/*
Query 5.31 Trajectories that have at least K (K >=2) continuous strictly
increasing sections of Pm25, followed by M (M>=2) continuously strictly
decreasing sections.
*/

-- Minimum increasing and decreasing sections
WITH Params(K, M) AS (
  SELECT 2, 3 ),
Ordered AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime) AS PrevPm25
  FROM GridCells ),
Trend AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    CASE
      WHEN Pm25 > PrevPm25 THEN 1 WHEN Pm25 < PrevPm25 THEN -1 ELSE 0
    END AS Trend
  FROM Ordered ),
Runs AS (
  SELECT *,
    SUM(NewRun) OVER (PARTITION BY TripId ORDER BY StartTime) AS RunId
  FROM (
    SELECT *,
      CASE
        WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId ORDER BY StartTime)
          THEN 0 ELSE 1
      END AS NewRun
      FROM Trend
      WHERE Trend <> 0 ) AS Temp ),
RunLengths AS (
  SELECT TripId, RunId, Trend, COUNT(*) AS RunLen
  FROM Runs
  GROUP BY TripId, RunId, Trend ),
SelectedRunPairs AS (
  SELECT r1.TripId, r1.RunId AS IncRun, r2.RunId AS DecRun
  FROM RunLengths r1, RunLengths r2, Params p 
  WHERE r2.TripId = r1.TripId AND r2.RunId = r1.RunId + 1 AND r1.Trend = 1 AND
    r1.RunLen >= p.K AND r2.Trend = -1 AND r2.RunLen >= p.M )
SELECT r.TripId, r.CellId, r.StartTime, r.EndTime, r.Pm25,
  CASE
    WHEN r.RunId = s.IncRun THEN 'increasing'
    WHEN r.RunId = s.DecRun THEN 'decreasing'
  END AS Phase
FROM Runs r, SelectedRunPairs s
WHERE s.TripId = r.TripId AND r.RunId IN (s.IncRun, s.DecRun)
ORDER BY r.TripId, r.StartTime;
  
-- (5023 rows)
-- Time: 307.512 ms

-------------------------------------------------------------------------------
/*
5.32 Trajectories that have at least three continuously increasing sections
with values Pm25 higher than 125, followed by two continuously decreasing
sections and such that in these sections the temperature was always higher
than 20 degrees.
*/

-- Order each trip temporally and expose the previous Pm25 value
WITH Ordered AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Attributes,
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime) AS PrevPm25
  FROM GridCells ),
-- Classify each section as increasing (+1), decreasing (-1), or neutral (0)
Trend AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Attributes,
    CASE
      WHEN Pm25 > PrevPm25 THEN  1 WHEN Pm25 < PrevPm25 THEN -1 ELSE 0
    END AS Trend
  FROM Ordered ),
-- Assign a RunId to maximal contiguous segments with the same monotonic trend
Runs AS (
  SELECT *, SUM(NewRun) OVER (PARTITION BY TripId ORDER BY StartTime) AS RunId
  FROM (
    SELECT *,
      CASE WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId 
        ORDER BY StartTime) THEN 0 ELSE 1
      END AS NewRun
    FROM Trend
    WHERE Trend <> 0 ) AS temp ),
-- Compute run lengths and validates Pm25 and temperature constraints per run
RunStats AS (
  SELECT TripId, RunId, Trend, COUNT(*) AS RunLen,
    bool_and(Pm25 > 125) FILTER (WHERE Trend = 1) AS IncPm25,
    bool_and((Attributes->>'Temperature')::numeric > 20) FILTER
      (WHERE Trend = -1) AS DecTemp
  FROM Runs
  GROUP BY TripId, RunId, Trend ),
-- Select adjacent increasing/decreasing runs that satisfy length and value conditions
SelectedRunPairs AS (
  SELECT r1.TripId, r1.RunId AS IncRun, r2.RunId AS DecRun
  FROM RunStats r1, RunStats r2
  WHERE r2.TripId = r1.TripId AND r2.RunId = r1.RunId + 1 AND
    r1.Trend =  1 AND r1.RunLen >= 3 AND r1.IncPm25 AND r2.Trend = -1 AND
      r2.RunLen >= 2 AND r2.DecTemp )
-- Return every section (CellId) participating in a valid pattern.
SELECT r.TripId, r.CellId, r.StartTime, r.EndTime, r.Pm25,
  (r.Attributes->>'Temperature')::numeric AS Temperature,
  CASE
    WHEN r.RunId = s.IncRun THEN 'Increasing'
    WHEN r.RunId = s.DecRun THEN 'Decreasing'
  END AS Phase
FROM Runs r, SelectedRunPairs s
WHERE s.TripId = r.TripId AND r.RunId IN (s.IncRun, s.DecRun)
ORDER BY r.TripId, r.StartTime;

-- (508 rows)
-- Time: 387.433 ms

-------------------------------------------------------------------------------
/*
Query 5.33. Trips that traversed at least twice the same cell with exactly
one different cell in between.
*/

-- Order each trip by time and expose the previous two cells
WITH Ordered(TripId, CellId, StartTime, Prev2Cell, PrevCell) AS (
  SELECT TripId, CellId, StartTime,
    LAG(CellId, 2) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(CellId, 1) OVER (PARTITION BY TripId ORDER BY StartTime)
    FROM GridCells )
SELECT TripId, Prev2Cell AS CellId1, PrevCell AS CellId2,
  CellId AS CellId3, StartTime
FROM Ordered
WHERE Prev2Cell IS NOT NULL AND CellId = Prev2Cell AND PrevCell <> CellId
ORDER BY TripId, StartTime;

-- (10478 rows)
-- Time: 120.140 ms

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
    FROM GridCells )
SELECT TripId, Prev3Cell AS CellA1, Prev2Cell AS CellB, PrevCell AS CellC,
  CellId AS CellA2, StartTime
FROM Ordered
WHERE Prev3Cell IS NOT NULL AND Prev2Cell IS NOT NULL AND
  PrevCell IS NOT NULL AND 
  CellId = Prev3Cell AND      -- A → B → C → A
  Prev2Cell <> PrevCell AND   -- B ≠ C
  Prev2Cell <> CellId AND     -- B ≠ A
  PrevCell <> CellId          -- C ≠ A
ORDER BY TripId, StartTime;

-- (102 rows)
-- Time: 107.600 ms

-------------------------------------------------------------------------------%%%%
/*
Query 5.35. Trips that started from a Pm25 lower than 130 and at some
point reached a value higher than 180.
*/

-- Order each trip and expose the first Pm25 value
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, RowNo) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY StartTime)
    FROM GridCells ),
-- Select trips whose first section starts with Pm25 < 130 and that later
-- reaches Pm25 > 180
SelectedTrips AS (
  SELECT DISTINCT o1.TripId
  FROM Ordered o1, Ordered o2
  WHERE o1.TripId = o2.TripId AND o1.RowNo = 1 AND o1.Pm25 < 130 AND
    o2.Pm25 > 180 )
-- Return the concrete sections satisfying the pattern
SELECT o.TripId, o.RowNo, o.CellId, o.StartTime, o.EndTime, o.Pm25,
  CASE
    WHEN o.RowNo = 1 THEN 'start (<130)'
    WHEN o.Pm25 > 180 THEN 'exceeds 180'
  END AS Role
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId AND (o.RowNo = 1 OR o.Pm25 > 180)
ORDER BY o.TripId, o.StartTime;

-- (819 rows)
-- Time: 144.715 ms

-------------------------------------------------------------------------------
/*
Query 5.36. Same as Query 5.35, but such that the elapsed time between
the increase of values is less than thirty minutes.
*/

-- Order each trip and assign a sequence number to each section
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, RowNo) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM GridCells ),
-- Identify the starting section of each trip with Pm25 < 130
Starts AS (
  SELECT TripId, CellId AS StartCell, StartTime, Pm25 AS StartPm25
  FROM Ordered
  WHERE RowNo = 1 AND Pm25 < 130 ),
-- Find for each trip the first section where Pm25 exceeds 180
FirstExceed AS (
  SELECT DISTINCT ON (TripId) TripId, CellId AS ExceedCell,
    StartTime AS ExceedTime, Pm25 AS ExceedPm25
  FROM Ordered
  WHERE Pm25 > 180
  ORDER BY TripId, StartTime ),
-- Keep only trips where the increase happens within 30 minutes
SelectedTrips(TripId, StartTime, ExceedTime, ElapsedTime) AS (
  SELECT s.TripId, s.StartTime, f.ExceedTime, (f.ExceedTime - s.StartTime)
  FROM Starts s, FirstExceed f
  WHERE f.TripId = s.TripId AND
    f.ExceedTime - s.StartTime < interval '30 minutes' )
-- Show the concrete sections satisfying the pattern with elapsed time
SELECT o.TripId, o.CellId, o.StartTime, o.EndTime, o.Pm25, s.ElapsedTime,
  CASE
    WHEN o.StartTime = s.StartTime THEN 'start (<130)'
    WHEN o.StartTime = s.ExceedTime THEN 'first >180'
    ELSE 'intermediate'
  END AS Role
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId AND o.StartTime BETWEEN s.StartTime AND s.ExceedTime
ORDER BY o.TripId, o.StartTime; 

-- (288 rows)
-- Time: 149.099 ms

-------------------------------------------------------------------------------
/*
Query 5.37. Trips traveling all their way under a Temperature higher
than 20 degrees and such that at in at least any two consecutive sections,
the Pm25 was higher than 150.
*/

-- Order each trip and expose the previous section values
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, Attributes,
  PrevCellId, PrevStartTime, PrevPm25, PrevAttributes) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25, Attributes,
    LAG(CellId) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(StartTime) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime),
    LAG(Attributes) OVER (PARTITION BY TripId ORDER BY StartTime)
  FROM GridCells ),
-- Keep only trips where ALL sections have temperature > 20
SelectedTrips AS (
  SELECT TripId
  FROM GridCells
  GROUP BY TripId
  HAVING bool_and((Attributes->>'Temperature')::numeric > 20) )
-- Return the concrete consecutive sections satisfying the condition
SELECT o.TripId,
  -- First section of the pair
  o.PrevCellId AS CellId1, o.PrevStartTime AS StartTime1, o.PrevPm25 AS Pm25_1,
  (o.PrevAttributes->>'Temperature')::numeric AS Temperature1,
  -- Second section of the pair
  o.CellId AS CellId2, o.StartTime AS StartTime2, o.Pm25 AS Pm25_2,
  (o.Attributes->>'Temperature')::numeric AS Temperature2
FROM Ordered o, SelectedTrips s
WHERE s.TripId = o.TripId AND o.PrevPm25 > 150 AND o.Pm25 > 150
ORDER BY o.TripId, o.PrevStartTime;

-- (3474 rows)
-- Time: 205.405 ms

-------------------------------------------------------------------------------
/*
Query 5.38. Trips that traversed at least three consecutive sections under
rainy conditions (rain > 0) with Pm25 higher than 150 and with humidity higher
than 70.
*/

-- Order each trip and extract the relevant variables
WITH Ordered(TripId, CellId, StartTime, EndTime, Pm25, Humidity, CloudCover,
    Rain) AS (
  SELECT TripId, CellId, StartTime, EndTime, Pm25,
    (Attributes->>'Humidity')::numeric, (Attributes->>'CloudCover')::numeric,
    (Attributes->>'Rain')::numeric
  FROM GridCells ),
-- Mark sections that satisfy all per-section constraints
Selected AS (
  SELECT *,
    CASE
      WHEN Pm25 > 150 AND Humidity > 70 AND rain > 0 THEN 1 ELSE 0
    END AS Valid
    FROM Ordered ),
Runs AS (
  -- Assigns a RunId to consecutive sections satisfying the constraints.
  SELECT *,
    SUM(NewRun) OVER (PARTITION BY TripId ORDER BY StartTime ) AS RunId
  FROM (
    SELECT *,
      CASE
        WHEN Valid = 1 AND LAG(Valid) OVER (PARTITION BY TripId ORDER BY
          StartTime) = 1 THEN 0 ELSE 1
      END AS NewRun
    FROM Selected ) AS Temp ),
-- Compute the length of each selected run
RunStats AS (
  SELECT TripId, RunId, COUNT(*) AS RunLen
  FROM Runs
  WHERE Valid = 1
  GROUP BY TripId, RunId
  HAVING COUNT(*) >= 3 )
-- Return the concrete sections belonging to the selected runs
SELECT r.TripId, r.CellId, r.StartTime, r.EndTime, r.Pm25, r.Humidity,
  r.CloudCover, r.Rain
FROM Runs r, RunStats s
WHERE s.TripId = r.TripId AND s.RunId = r.RunId AND r.Valid = 1
ORDER BY r.TripId, r.StartTime; 

-- (234 rows)
-- Time: 464.412 ms

-------------------------------------------------------------------------------
