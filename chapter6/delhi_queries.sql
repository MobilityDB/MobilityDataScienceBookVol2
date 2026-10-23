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

/*****************************************************************************
 * Queries over the Delhi trips of chapter 6, in the order of the chapter.
 * Each query is preceded by its statement and the pattern it expresses. The
 * discrete version reads the observations (TripPoints) or the cell visits
 * (TripCells, TripCellsSeq), and the continuous version reads the temporal
 * values (Trips, TripTiles, TripTilesSeq). The tables are built by
 * delhi_load.sql; delhi_districts.sql holds the district patterns.
 *****************************************************************************/

SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';

-------------------------------------------------------------------------------

/*
 * que:grid-allincrease. Trips during which the PM2.5 increases continuously.

  IncrPm25: Trip[sign(derivative(Pm25)) > 0]
  Trip[IncrPm25 AND getTime(IncrPm25) = getTime(Trip)]
*/

-- Discrete version
WITH TrendPm25(TripId, CellId, Weather, Pm25, Trend) AS (
  SELECT TripId, CellId, Weather, Pm25, SIGN(Pm25 - LAG(Pm25)
    OVER (PARTITION BY TripId ORDER BY StartTime))
  FROM TripCells ),
SelectedTrip(TripId) AS (
  SELECT TripId FROM TrendPm25 GROUP BY TripId
  HAVING COUNT(*) >= 2 AND COUNT(*)
    FILTER (WHERE Trend <= 0) = 0 )
SELECT TripId, array_agg(CellId ORDER BY StartTime) AS Cells,
  array_agg(ROUND(Pm25::numeric, 2) ORDER BY StartTime) AS Pm25Seq
FROM TripCells WHERE TripId IN (SELECT TripId FROM SelectedTrip)
  GROUP BY TripId ORDER BY TripId;
-- 12 | {35,34,44} | {399.44,424.71,469.26} ...

-- Continuous version
WITH Trip(TripId, Pm25) AS ( SELECT TripId, mergeAgg(Pm25)
  FROM TripTiles GROUP BY TripId ),
SelectedTrip(TripId) AS ( SELECT TripId FROM Trip
  WHERE trend(Pm25) %> 0 )
SELECT TripId, tintSeq(array_agg(tint(CellId, lower(AtTime))
  ORDER BY AtTime)) AS Cells,
  merge(array_agg(Pm25 ORDER BY AtTime)) AS Pm25
FROM TripTiles WHERE TripId IN (SELECT TripId FROM SelectedTrip)
  GROUP BY TripId ORDER BY TripId;
/* 19 | [39@2020-11-04 21:08:26] | {[432@2020-11-04 21:08:26,
  433@2020-11-04 21:08:29]} ... */

-------------------------------------------------------------------------------

/*
 * que:grid-incr-decr. Trips where the Pm25 increases for at least 1.5
 * minutes and then decreases for at least 1.5 minutes, such that in both
 * episodes, the Pm25 is higher than 125 and the temperature is higher than
 * 20 degrees.

  IncrPm25: Trip[sign(derivative(Pm25)) > 0]
  DecrPm25: Trip[sign(derivative(Pm25)) < 0]
  IncrDecrPm25: Trip[before([IncrPm25
    AND duration(IncrPm25) >= '1.5 minutes'],
    [DecrPm25 AND duration(DecrPm25) >= '1.5 minutes'])]
  Trip[IncrDecrPm25 AND Pm25 > 125 AND Temperature > 20]
*/

-- Discrete version
WITH Restricted(TripId, StartTime, EndTime, CellId, Pm25) AS (
  SELECT TripId, StartTime, EndTime, CellId, Pm25 FROM TripCells
  WHERE Pm25 > 125 AND (Weather->>'Temperature')::float > 20 ),
TrendPm25(TripId, StartTime, EndTime, CellId, Pm25, Trend) AS (
  SELECT TripId, StartTime, EndTime, CellId, Pm25, SIGN(Pm25 -
    (LAG(Pm25) OVER (PARTITION BY TripId ORDER BY StartTime)))
      FROM Restricted ),
EpisodeStart(TripId, StartTime, EndTime, CellId, Pm25, Trend,
  NewEpisode) AS (
  SELECT TripId, StartTime, EndTime, CellId, Pm25, Trend, CASE
    WHEN Trend IS NULL OR
    Trend <> LAG(Trend) OVER (PARTITION BY TripId
      ORDER BY StartTime) THEN 1 ELSE 0 END FROM TrendPm25 ),
Episode(TripId, EpisodeId, StartTime, EndTime, CellId, Pm25,
  Trend) AS (
  SELECT TripId, SUM(NewEpisode) OVER (PARTITION BY TripId
    ORDER BY StartTime), StartTime, EndTime,
   CellId, Pm25, Trend FROM EpisodeStart ),
EpisodeDuration(TripId, EpisodeId, StartTime, EndTime, Trend,
  Duration, Cells, Pm25seq) AS (
  SELECT TripId, EpisodeId, MIN(StartTime), MAX(EndTime),
    MIN(Trend), MAX(EndTime) -MIN(StartTime),
    array_agg(CellId ORDER BY StartTime),
      array_agg(ROUND(Pm25::numeric, 2) ORDER BY StartTime)
      FROM Episode
  GROUP BY TripId, EpisodeId
    HAVING MAX(StartTime) - MIN(StartTime) >= interval
    '1.5 minutes' AND COUNT(*) >= 2 ),
EpisodePair(TripId, IncrEpisode, DecrEpisode) AS (
  SELECT e1.TripId, e1.EpisodeId, e2.EpisodeId
    FROM EpisodeDuration e1, EpisodeDuration e2
  WHERE e1.TripId = e2.TripId AND e1.EpisodeId + 1 = e2.EpisodeId
    AND e1.Trend = 1 AND e2.Trend = -1 )
SELECT e.TripId, EpisodeId, StartTime, EndTime, Duration, Cells,
  Trend, Pm25seq
FROM EpisodeDuration e, EpisodePair p
WHERE e.TripId = p.TripId AND e.EpisodeId IN (p.IncrEpisode,
  p.DecrEpisode) ORDER BY e.TripId;
/* 4 | 1 | 2020-11-03 08:23:32 2020-11-03 09:24:40 | 01:01:08 |
  {87,77} | 1 | {157.19,162.33}
  4 | 2 | 2020-11-03 09:24:43 2020-11-03 09:29:36 | 00:04:53 |
    {78,77} | -1 | {161.15,151.91} ... */

-- Continuous version
WITH Trip(TripId, Cells, Pm25, Weather) AS (
  SELECT TripId, mergeAgg(tint(CellId, AtTime)), mergeAgg(Pm25),
    mergeAgg(Weather) FROM TripTiles GROUP BY TripId ),
Restricted(TripId, Cells, Pm25) AS (
  SELECT TripId, Cells, atTime(Pm25,
    whenTrue(Pm25 #> 125) * whenTrue(tfloat(Weather,
    'Temperature', 'step') #> 20))
  FROM Trip
  WHERE whenTrue(Pm25 #> 125) IS NOT NULL
    AND whenTrue(tfloat(Weather, 'Temperature',
    'step') #> 20) IS NOT NULL ),
Incr(TripId, Cells, Pm25) AS (
  SELECT TripId, Cells, unnest(sequences(atTime(Pm25,
    whenTrue(segmentMinDuration(atValue(trend(Pm25) #> 0, true),
    interval '1.5 minutes', false))))) FROM Restricted ),
Decr(TripId, Pm25) AS (
  SELECT TripId, unnest(sequences(atTime(Pm25,
    whenTrue(segmentMinDuration(atValue(trend(Pm25) #< 0, true),
    interval '1.5 minutes', false))))) FROM Restricted ),
Pair(TripId, Cells, PairNo, Incr, Decr) AS (
  SELECT i.TripId, i.Cells, ROW_NUMBER()
    OVER (PARTITION BY i.TripId ORDER BY startTimestamp(i.Pm25)),
    i.Pm25, d.Pm25
  FROM Incr i, Decr d WHERE i.TripId = d.TripId
    AND endTimestamp(i.Pm25) = startTimestamp(d.Pm25) )
SELECT p.TripId, p.PairNo, getTime(e.Pm25),
  duration(getTime(e.Pm25)), valueSet(atTime(p.Cells,
  getTime(e.Pm25))), e.Trend,
  e.Pm25 FROM Pair p, LATERAL (VALUES (1, p.Incr), (-1,
    p.Decr)) AS e(Trend, Pm25)
  ORDER BY p.TripId, p.PairNo, e.Trend DESC;
/* 2210 | 1 | {(2020-11-29 13:24:14.44,
  2020-11-29 13:27:02)} | 00:02:47.56 | {47} | 1 | (125@2020-11-29
  13:24:14.44, ...*/

-------------------------------------------------------------------------------

/*
 * que:grid-span. Trips that have at some point a Pm25 lower than 100 and
 * later reach a value higher than 400, such that the elapsed time between
 * the increase of values is less than one minute.

  StartPm25: Trip[Pm25 < 100]
  EndPm25: Trip[Pm25 > 400]
  Trip[before(StartPm25, EndPm25)
    AND lower(EndPm25) - lower(StartPm25) < interval '1 minute']
*/

-- Discrete version
WITH StartPm25(TripId, StartStep, StartCell, StartTime,
  StartPm25) AS (
  SELECT TripId, StepNo, CellId, StartTime, Pm25 FROM TripCells c1
  WHERE StepNo = ( SELECT MIN(StepNo) FROM TripCells c2
    WHERE c1.TripId = c2.Tripid AND Pm25 < 100 ) ),
EndPm25(TripId, EndStep, EndCell, EndTime, EndPm25) AS (
  SELECT TripId, StepNo, CellId, EndTime, Pm25 FROM TripCells c1
  WHERE StepNo = ( SELECT MIN(StepNo) FROM TripCells c2
    WHERE c1.TripId = c2.Tripid AND Pm25 > 400 ) ),
Episode(TripId, StartTime, EndTime, Duration) AS (
  SELECT s.TripId, StartTime, EndTime, EndTime - StartTime
    FROM StartPm25 s, EndPm25 e
  WHERE s.TripId = e.Tripid AND StartTime < EndTime
    AND EndTime - StartTime < '1 minute' )
SELECT t.TripId, e.StartTime, e.EndTime, e.Duration,
  array_agg(t.CellId ORDER BY t.StartTime) AS Cells,
  array_agg(ROUND(t.Pm25::numeric, 2)
    ORDER BY t.StartTime) AS Pm25seq
FROM TripCells t, Episode e WHERE t.TripId = e.TripId
  AND t.StartTime BETWEEN e.StartTime AND e.EndTime
GROUP BY t.TripId, e.StartTime, e.EndTime, e.Duration
  ORDER BY TripId, StartTime;
/* 14365 | 2020-11-20 11:18:52 | 2020-11-20 11:18:54 |
  00:00:02 | {40,39} | {55.00,503.00}
  14373 | 2020-11-20 11:19:12 | 2020-11-20 11:19:13 |
    00:00:01 | {40,39} | {64.00,432.00} ... */

-- Continuous version
WITH StartPm25(TripId, StartStep, StartCell, StartTime,
  StartPm25) AS (
  SELECT TripId, StepNo, CellId, lower(AtTime), Pm25
    FROM TripTiles t1
  WHERE StepNo = ( SELECT MIN(StepNo) FROM TripTiles t2
    WHERE t1.TripId = t2.Tripid AND Pm25 ?< 100 ) ),
EndPm25(TripId, EndStep, EndCell, EndTime, EndPm25) AS (
  SELECT TripId, StepNo, CellId, upper(AtTime), Pm25
    FROM TripTiles t1
  WHERE StepNo = ( SELECT MIN(StepNo) FROM TripTiles t2
    WHERE t1.TripId = t2.Tripid AND Pm25 ?> 400 ) ),
Episode(TripId, AtTime, Duration) AS (
  SELECT s.TripId, span(StartTime, EndTime),
    duration(span(StartTime, EndTime))
  FROM StartPm25 s, EndPm25 e WHERE s.TripId = e.Tripid
    AND StartTime < EndTime AND EndTime - StartTime < '1 minute' )
SELECT t.TripId, e.AtTime, e.Duration,
  tintSeq(array_agg(tint(CellId, lower(t.AtTime))
  ORDER BY t.AtTime)),
  array_agg(ROUND(t.Pm25, 2) ORDER BY t.AtTime) AS Pm25seq
FROM TripTiles t, Episode e WHERE t.TripId = e.TripId
  AND t.AtTime && e.AtTime
GROUP BY t.TripId, e.AtTime, e.Duration ORDER BY TripId, AtTime;
/* 14365 | [2020-11-20 11:18:52, 2020-11-20 11:18:54) | 00:00:02 |
  [40@2020-11-20 11:18:52, 39@2020-11-20 11:18:52.662855] |
  {"{[55@2020-11-20 11:18:52, 203.48@2020-11-20 11:18:52.662855]}",
   "{(203.48@2020-11-20 11:18:52.662855, 503@2020-11-20 11:18:54]}"}
  ... */

-------------------------------------------------------------------------------

/*
 * que:grid-higher. Trips that travel all their way under a temperature
 * higher than 25 degrees such that in at least two episodes longer than ten
 * minutes, the Pm25 is higher than 150.

  HighTemp: Trip[Temperature > 25]
  TripTemp: Trip[HighTemp AND getTime(HighTemp) = getTime(Trip)]
  HighPm25: Trip[TripTemp AND Pm25 > 150]
  Episode: Trip[HighPm25
    AND duration(HighPm25) > interval '10 minutes']
  Trip[before(Episode, Episode+)]
*/

-- Discrete version
WITH TripTemp(TripId) AS (
  SELECT TripId FROM TripCells GROUP BY TripId
    HAVING MIN((Weather->>'Temperature')::numeric) > 25 ),
LowerPm25(TripId, StartTime, EndTime, CellId, Pm25,
  StartEpisode) AS (
  SELECT TripId, StartTime, EndTime, CellId, Pm25, CASE
    WHEN Pm25 <= 150 OR LAG(Pm25) OVER
    (PARTITION BY TripId ORDER BY StartTime) <= 150 THEN 1 ELSE 0
      END
  FROM TripCells WHERE TripId IN (SELECT TripId FROM TripTemp) ),
Episode(TripId, EpisodeId, StartTime, EndTime, CellId, Pm25) AS (
  SELECT TripId, SUM(StartEpisode) OVER (PARTITION BY TripId
    ORDER BY StartTime), StartTime, EndTime, CellId, Pm25
  FROM LowerPm25 ),
Pattern(TripId, EpisodeId, StartTime, EndTime, Duration, Cells,
  Pm25seq) AS (
  SELECT TripId, EpisodeId, MIN(StartTime), MAX(EndTime),
    MAX(EndTime) - MIN(StartTime),
    array_agg(CellId ORDER BY StartTime),
      array_agg(ROUND(Pm25::numeric, 2) ORDER BY StartTime)
  FROM Episode WHERE Pm25 > 150 GROUP BY TripId, EpisodeId
  HAVING MAX(EndTime) - MIN(StartTime) >= interval '10 minutes'
    AND COUNT(*) >= 2 ),
SelectedTrip(TripId) AS ( SELECT TripId FROM Pattern
  GROUP BY TripId HAVING COUNT(*) >= 2 )
SELECT TripId, EpisodeId, StartTime, EndTime, Duration, Cells,
  Pm25seq FROM Pattern
WHERE TripId IN (SELECT TripId FROM SelectedTrip)
  ORDER BY TripId, StartTime;

-- Continuous version
WITH Trip(TripId, Pm25, Weather) AS (
  SELECT TripId, mergeAgg(Pm25), mergeAgg(Weather) FROM TripTiles
  GROUP BY TripId ),
TripTemp(TripId, Pm25) AS ( SELECT TripId, Pm25 FROM Trip
  WHERE tfloat(Weather, 'Temperature', 'step') %> 25 ),
Episode(TripId, EpisodeId, AtTime, Pm25) AS (
  SELECT TripId, ep.ord, ep.s, atTime(Pm25, ep.s)
    FROM TripTemp, unnest(spans(whenTrue(Pm25 #> 150)))
    WITH ORDINALITY AS ep(s, ord)
      WHERE duration(ep.s) >= interval '10 minutes' ),
SelectedTrip(TripId) AS ( SELECT TripId FROM Episode
  GROUP BY TripId HAVING COUNT(*) >= 2 )
SELECT e.TripId, e.EpisodeId, e.AtTime, duration(e.AtTime),
  (SELECT tintSeq(array_agg(tint(t.CellId, lower(t.AtTime))
    ORDER BY t.AtTime))
   FROM TripTiles t WHERE t.TripId = e.TripId
     AND t.AtTime && e.AtTime), e.Pm25
FROM Episode e WHERE e.TripId IN (SELECT TripId FROM SelectedTrip)
  ORDER BY e.TripId, lower(e.AtTime);

-------------------------------------------------------------------------------

/*
 * que:grid-raintemphm. Trips such that there is at least a 30-minute episode
 * where the Pm25 is higher than 300 in cloudy conditions and with humidity
 * higher than 80%.

  HighPm25: Trip[Pm25 > 300]
  Episode: Trip[HighPm25
    AND duration(HighPm25) > interval '30 minutes']
  Trip[Episode AND CloudCover > 0 AND Humidity > 80]
*/

-- Discrete version
WITH Segment(TripId, StartTime, EndTime, Pm25, CloudCover,
  Humidity, Valid) AS (
  SELECT TripId, StartTime, EndTime, Pm25,
    (Weather->>'CloudCover')::numeric,
    (Weather->>'Humidity')::numeric, CASE
    WHEN Pm25 > 300 AND (Weather->>'CloudCover')::numeric > 0
      AND (Weather->>'Humidity')::numeric > 80
    THEN 1 ELSE 0 END FROM TripCells ),
SegmentPrev(TripId, StartTime, EndTime, Pm25, CloudCover,
  Humidity, Valid, PrevValid) AS (
  SELECT *, LAG(Valid) OVER (PARTITION BY TripId
    ORDER BY StartTime) FROM Segment ),
Episode(TripId, EpisodeId, StartTime, EndTime, Pm25, CloudCover,
  Humidity, Valid, PrevValid) AS (
  SELECT TripId, SUM(CASE WHEN Valid = PrevValid THEN 0 ELSE 1
    END) OVER (PARTITION BY TripId ORDER BY StartTime),
    StartTime, EndTime, Pm25, CloudCover, Humidity, Valid,
      PrevValid FROM SegmentPrev )
SELECT TripId, EpisodeId, MIN(StartTime) AS StartTime,
  MAX(EndTime) AS EndTime,
  MAX(StartTime) - MIN(StartTime) AS Duration, array_agg(Pm25
    ORDER BY StartTime) AS Pm25Seq,
  array_agg(CloudCover ORDER BY StartTime) AS CloudCoverSeq,
    array_agg(Humidity ORDER BY StartTime) AS HumiditySeq
FROM Episode GROUP BY TripId, EpisodeId
HAVING MAX(EndTime) - MIN(StartTime) >= '30 minutes'
  AND BOOL_AND(Valid = 1) ORDER BY TripId, StartTime;

-------------------------------------------------------------------------------

/*
 * que:grid_cell_patt1. Trips that traverse at least twice the same cell with
 * exactly one different cell in between.

  [Trips]; CellId = @c AND @c = prev(prev(@c)) AND @c <> prev(@c)
*/

-- Discrete version
SELECT s.TripId, g.Pos, s.CellSeq[g.Pos : g.Pos + 2] AS MatchSeq
FROM TripCellsSeq s CROSS JOIN LATERAL generate_series(1,
  array_length(s.CellSeq, 1) - 2) AS g(Pos)
WHERE s.CellSeq[g.Pos] = s.CellSeq[g.Pos + 2]
  AND s.CellSeq[g.Pos] <> s.CellSeq[g.Pos + 1] ORDER BY s.TripId;
/* 1 | 1 | {47,46,47}
  1 | 2 | {46,47,46} ... */

-- Discrete version
SELECT * FROM TripCellsSeq WHERE TripId = 1;
-- 1 | {47,46,47,46}

-- Discrete version
WITH AllMatches AS (
  SELECT s.TripId, g.Pos, s.CellSeq[g.Pos:g.Pos + 2] AS MatchSeq
  FROM TripCellsSeq s CROSS JOIN LATERAL generate_series(1,
    array_length(s.CellSeq, 1) - 2) AS g(Pos)
  WHERE s.CellSeq[g.Pos] = s.CellSeq[g.Pos + 2]
    AND s.CellSeq[g.Pos] <> s.CellSeq[g.Pos + 1] ),
Ranked AS ( SELECT *, LAG(Pos) OVER (PARTITION BY TripId
  ORDER BY Pos) AS PrevPos FROM AllMatches )
SELECT TripId, Pos, MatchSeq FROM Ranked WHERE PrevPos IS NULL
  OR Pos >= PrevPos + 3 ORDER BY TripId, Pos;
-- 1 | 1 | {47,46,47} ...

-- Discrete version
WITH Expanded (TripId, Pos, Val, NextPos, CellSeq) AS (
  SELECT s.TripId, u.Pos, u.Val, LEAD(u.Pos)
    OVER (PARTITION BY s.TripId, u.Val ORDER BY u.Pos), s.CellSeq
  FROM TripCellsSeq s CROSS JOIN
    LATERAL unnest(s.CellSeq) WITH ORDINALITY AS u(Val, Pos))
SELECT TripId, Pos AS StartPos, NextPos AS EndPos,
  CellSeq[Pos:NextPos] AS MatchSeq
FROM Expanded WHERE NextPos IS NOT NULL ORDER BY TripId, Pos;
/* 4 | 4 | 24 |
  {46,56,57,47,57,58,57,67,77,78,77,87,77,78,77,67,57,58,57,47,46}
  ...
  4 | 9 | 21 | {58,57,67,77,78,77,87,77,78,77,67,57,58} ... */

-- Continuous version
SELECT s.TripId, g.Pos, s.CellSeq[g.Pos : g.Pos + 2] AS MatchSeq
FROM TripTilesSeq s CROSS JOIN LATERAL generate_series(1,
  array_length(s.CellSeq, 1) - 2) AS g(Pos)
WHERE s.CellSeq[g.Pos] = s.CellSeq[g.Pos + 2]
  AND s.CellSeq[g.Pos] <> s.CellSeq[g.Pos + 1] ORDER BY s.TripId;

-------------------------------------------------------------------------------

/*
 * que:point-development. Trips that traversed one district with the
 * following development of spatiotemporal predicates: Disjoint -> Meets ->
 * Inside -> Meets -> Disjoint.
*/

-- Continuous version
WITH Meets(TripId, Name, AtTimestamp) AS (
  SELECT t.TripId, d.Name,
    lower(unnest(spans(whenTrue(tIntersects(t.Trip,
    d.Boundary)))))
  FROM Trips t, Districts d WHERE eIntersects(t.Trip, d.Boundary)
    ORDER BY t.TripId, d.Name ),
ContainedBy(TripId, Name, AtTime) AS (
  SELECT t.TripId, d.Name, unnest(spans(whenTrue(tContains(d.Geom,
    t.Trip))))
  FROM Trips t, Districts d WHERE eIntersects(t.Trip, d.Geom)
    ORDER BY t.TripId, d.Name )
SELECT m1.TripId, m1.Name, m1.AtTimestamp AS EnterTime,
  c.AtTime AS InsideTime,
  m2.AtTimestamp AS LeaveTime FROM Meets m1, ContainedBy c,
    Meets m2
WHERE m1.TripId = c.TripId AND m1.Name = c.Name
  AND m2.TripId = c.TripId AND m2.Name = c.Name AND
  m1.AtTimestamp = lower(c.AtTime)
    AND m2.AtTimestamp = upper(c.AtTime)
    ORDER BY m1.TripId, m1.Name;
/* 4 | Shahdara | 2020-11-03 10:53:57.4809 | (2020-11-03
  10:53:57.4809 ,
  2020-11-03 11:37:55.6363) | 2020-11-03 11:37:55.6363
  4 | Shahdara | 2020-11-03 11:38:25.94 | (2020-11-03
    11:38:25.9401,
    2020-11-03 11:44:14.89857) | 2020-11-03 11:44:14.89 */

-------------------------------------------------------------------------------

SELECT COUNT(*) FROM ( SELECT TripId, CellId FROM TripCells EXCEPT
  SELECT TripId, CellId FROM TripTiles ) AS NoDiscr;
-- 0
SELECT COUNT(*) FROM ( SELECT TripId, CellId FROM TripTiles EXCEPT
  SELECT TripId, CellId FROM TripCells ) AS NoCont;
-- 93

-------------------------------------------------------------------------------

WITH Discrete(TripId, CellId, Dur) AS (
  SELECT TripId, CellId, SUM(EndTime - StartTime) FROM TripCells
    GROUP BY TripId, CellId ),
Continuous(TripId, CellId, Dur) AS (
  SELECT TripId, CellId, SUM(upper(Sp) - lower(Sp))
  FROM ( SELECT TripId, CellId, unnest(spans(AtTime)) AS Sp
    FROM TripTiles ) AS S GROUP BY TripId, CellId )
SELECT COUNT(*) FILTER (WHERE D.Dur < C.Dur) AS Shorter, COUNT(*)
  FILTER (WHERE D.Dur = C.Dur) AS Equal,
  COUNT(*) FILTER (WHERE D.Dur > C.Dur) AS Longer FROM Discrete D
    JOIN Continuous C USING (TripId, CellId);
-- 28962 | 21726 | 0

-------------------------------------------------------------------------------

/*
 * que:point-incr. Trips during which the Pm25 increases continuously.
*/

-- Discrete version
WITH Segments(TripId, T, Pm25, NextPm25) AS (
  SELECT TripId, T, Pm25, LEAD(Pm25) OVER (PARTITION BY TripId
    ORDER BY T) FROM TripPoints )
SELECT TripId, MIN(T) AS StartTime, MAX(T) AS EndTime,
  array_agg(Pm25 ORDER BY T) AS Pm25Seq FROM Segments
WHERE NextPm25 IS NOT NULL GROUP BY TripId
  HAVING bool_and(Pm25 < NextPm25) ORDER BY TripId, StartTime;
/* 19 | 2020-11-04 21:08:26 | 2020-11-04 21:08:26 | {432}
  81 | 2020-11-07 10:28:57 | 2020-11-07 10:28:57 | {397} ... */

-- Continuous version
SELECT TripId, Pm25 FROM Trips WHERE trend(Pm25) %> 0;

-------------------------------------------------------------------------------

/*
 * que:point-incr-decr-global. Trips where the Pm25 increases for at least
 * 1.5 minutes and then decreases for at least 1.5 minutes, such that in both
 * episodes the Pm25 is higher than 125 and the temperature is higher than 20
 * degrees.
*/

-- Discrete version
WITH Segment(TripId, T, NextT, Pm25, NextPm25, Temperature,
  NextTemperature) AS (
  SELECT TripId, T, LEAD(T) OVER w, Pm25, LEAD(Pm25)
    OVER w, (Weather->>'Temperature')::numeric,
    ((LEAD(Weather) OVER w)->>'Temperature')::numeric
  FROM TripPoints WINDOW w AS (PARTITION BY TripId ORDER BY T) ),
Crossing(TripId, T, NextT, Pm25, NextPm25, Temperature, NextTemperature,
  CrossT) AS (
  SELECT *, CASE WHEN (Pm25 < 125 AND 125 < nextPm25)
    THEN T + (NextT - T) * (125 - Pm25) / (nextPm25 - Pm25)
    WHEN (Pm25 > 125 AND 125 > nextPm25)
      THEN T + (NextT - T) * (Pm25 - 125) / (Pm25 - nextPm25) END
  FROM Segment WHERE NextT IS NOT NULL ),
ClippedSegment(TripId, T, NextT, Pm25, NextPm25, Temperature,
  NextTemperature) AS (
  SELECT TripId, CASE WHEN Pm25 > 125 THEN T ELSE CrossT END,
    CASE WHEN NextPm25 > 125 THEN NextT ELSE CrossT
      END, GREATEST(Pm25, 125),
    GREATEST(NextPm25, 125), Temperature, NextTemperature FROM Crossing
      WHERE GREATEST(Pm25, nextPm25) > 125 ),
TrendPm25(TripId, T, NextT, Pm25, NextPm25, Temperature, NextTemperature,
  Trend) AS (
  SELECT TripId, T, NextT, Pm25, NextPm25, Temperature, NextTemperature,
    SIGN(nextPm25 - Pm25)
  FROM ClippedSegment WINDOW w AS (PARTITION BY TripId
    ORDER BY T) ),
EpisodeStart(TripId, T, NextT, Pm25, NextPm25, Temperature, NextTemperature,
  Trend, NewEpisode) AS (
  SELECT *, CASE WHEN Trend = LAG(Trend) OVER (PARTITION BY TripId
    ORDER BY T) THEN 0 ELSE 1 END
  FROM TrendPm25 ),
Episode(TripId, EpisodeId, T, NextT, Pm25, NextPm25, Temperature,
  NextTemperature, Trend) AS (
  SELECT TripId, SUM(NewEpisode) OVER (PARTITION BY TripId
    ORDER BY T), T, NextT, Pm25, NextPm25,
    Temperature, NextTemperature, Trend FROM EpisodeStart ),
EpisodeTime(TripId, EpisodeId, Trend, StartTime, EndTime,
  StartPm25, EndPm25, StartTemperature, EndTemperature, Duration) AS (
  SELECT TripId, EpisodeId, Trend, MIN(T), MAX(NextT), MIN(Pm25),
    MAX(NextPm25), MIN(Temperature), MAX(NextTemperature),
    MAX(NextT) - MIN(T) FROM Episode
      GROUP BY TripId, EpisodeId, Trend
  HAVING MAX(NextT) - MIN(T) >= '1.5 minutes'
    AND BOOL_AND(LEAST(NextTemperature, Temperature) > 20) ),
Pattern(TripId, IncrEpisode, DecrEpisode) AS (
  SELECT r1.TripId, r1.EpisodeId AS IncrEpisode,
    r2.EpisodeId AS DecrEpisode FROM EpisodeTime r1,
    EpisodeTime r2
  WHERE r1.TripId = r2.TripId AND r1.Trend = 1 AND r2.Trend = -1
    AND r1.EndTime = r2.StartTime )
SELECT e.TripId, e.EpisodeId, e.Trend, e.StartTime, e.EndTime,
  e.Duration, e.StartPm25, e.EndPm25, e.StartTemperature, e.EndTemperature
FROM EpisodeTime e, Pattern s
WHERE s.TripId = e.TripId AND e.EpisodeId IN (s.IncrEpisode,
  s.DecrEpisode) ORDER BY e.TripId, e.EpisodeId;
/* 2210 | 259 |  1 | 2020-11-29 13:24:14.44 | 2020-11-29 13:27:02 |
  00:02:47.56 | 125 | 170 | 23 | 23
  2210 | 260 | -1 | 2020-11-29 13:27:02 | 2020-11-29 13:28:33 |
  00:01:31 | 169 | 169 | 23 | 23 ... */

-- Continuous version
WITH RestTrips(TripId, Pm25) AS (
  SELECT TripId, atTime(Pm25,
    whenTrue(Pm25 #> 125) * whenTrue(tfloat(Weather,
    'Temperature', 'step') #> 20)) FROM Trips
  WHERE whenTrue(Pm25 #> 125) IS NOT NULL
    AND  whenTrue(tfloat(Weather, 'Temperature',
    'step') #> 20) IS NOT NULL ),
IncrPm25(TripId, Pm25) AS (
  SELECT TripId, unnest(sequences(atTime(Pm25,
    whenTrue(segmentMinDuration(atValue(trend(Pm25) #> 0, true),
      interval '1.5 minute', false))))) FROM RestTrips ),
DecrPm25(TripId, Pm25) AS (
  SELECT TripId, unnest(sequences(atTime(Pm25,
    whenTrue(segmentMinDuration(atValue(trend(Pm25) #< 0, true),
      interval '1.5 minute', false))))) FROM RestTrips ),
Pattern(TripId, PairNo, Incr, Decr) AS (
  SELECT i.TripId, ROW_NUMBER() OVER (PARTITION BY i.TripId
    ORDER BY startTimestamp(i.Pm25)), i.Pm25, d.Pm25
  FROM IncrPm25 i, DecrPm25 d WHERE i.TripId = d.TripId
    AND endTimestamp(i.Pm25) = startTimestamp(d.Pm25) )
SELECT p.TripId, p.PairNo, e.Trend,
  startTimestamp(e.Pm25) AS StartTime,
  endTimestamp(e.Pm25) AS EndTime,
    duration(getTime(e.Pm25)) AS Duration,
  startValue(e.Pm25) AS StartPm25, endValue(e.Pm25) AS EndPm25
FROM Pattern p, LATERAL (VALUES (1, p.Incr), (-1,
  p.Decr)) AS e(Trend, Pm25) ORDER BY p.TripId, p.PairNo,
  e.Trend DESC;

-------------------------------------------------------------------------------

/*
 * que:point-span. Trips that have at some point the Pm25 lower than 100 and
 * later reach a value higher than 400, such that the elapsed time between
 * the increase of values is less than thirty minutes.
*/

-- Discrete version
WITH StartPm25 AS ( SELECT TripId, MIN(T) AS StartTime
  FROM TripPoints WHERE pm25 < 100 GROUP BY TripId ),
EndPm25 AS (
  SELECT p.TripId, MIN(T) AS EndTime
    FROM TripPoints p, StartPm25 s
  WHERE p.TripId = s.TripId AND p.T >= s.StartTime AND pm25 > 400
    GROUP BY p.TripId )
SELECT p.TripId, s.StartTime, e.EndTime, array_agg(p.pm25
  ORDER BY p.T) AS Pm25Seq
FROM TripPoints p, StartPm25 s, EndPm25 e
  WHERE p.TripId = s.TripId AND s.TripId = e.TripId AND
  s.StartTime < e.EndTime AND p.T BETWEEN s.StartTime
    AND e.EndTime AND EndTime - StartTime < '30 minutes'
GROUP BY p.TripId, s.StartTime, e.EndTime ORDER BY p.TripId;
/* 14365 | 2020-11-20 11:18:52 | 2020-11-20 11:18:54 |
  {55,503} ...
  14373 | 2020-11-20 11:19:12 | 2020-11-20 11:19:13 | {64,432}
    ... */

-- Continuous version
WITH StartPm25(TripId, StartTime, Pm25) AS (
  SELECT TripId, lower(whenTrue(Pm25 #< 100)),
    afterTimestamp(Pm25, lower(whenTrue(Pm25 #< 100)), false)
  FROM Trips WHERE whenTrue(Pm25 #< 100) IS NOT NULL ),
StartEndPm25(TripId, StartTime, EndTime) AS (
  SELECT TripId, StartTime, lower(whenTrue(Pm25 #> 400))
    FROM StartPm25 WHERE whenTrue(Pm25 #> 400) IS NOT NULL )
SELECT t.TripId, atTime(Pm25, span(startTime, endTime))
  FROM Trips t, StartEndPm25 m
WHERE t.TripId = m.TripId AND startTime < endTime
  AND EndTime - StartTime < interval '30 minutes' ORDER BY TripId;

-------------------------------------------------------------------------------

/*
 * que:point-higher-global. Trips that travel all their way under a
 * temperature higher than 25 degrees such that in at least two episodes
 * longer than ten minutes, the Pm25 is higher than 150.
*/

-- Continuous version
WITH Episode(TripId, AtTime) AS (SELECT TripId,
  unnest(spans(whenTrue(Pm25 #> 150))) FROM Trips
  WHERE tfloat(Weather, 'Temperature', 'step') %> 25
    AND whenTrue(Pm25 #> 150) IS NOT NULL ),
Pattern(TripId, AtTime) AS ( SELECT TripId, AtTime  FROM Episode
  WHERE duration(AtTime) >= interval '10 minutes' )
SELECT TripId, ROW_NUMBER() OVER (PARTITION BY TripId
  ORDER BY AtTime) AS EpisodeId,
  lower(AtTime) AS StartTime, upper(AtTime) AS EndTime,
    duration(AtTime) AS Duration
FROM Pattern
WHERE TripId IN (SELECT TripId FROM Pattern GROUP BY TripId
  HAVING COUNT(*) >= 2 ) ORDER BY TripId, AtTime;

-------------------------------------------------------------------------------

/*
 * que:point-weather. Trips such that there is at least a 30-minute episode
 * where the Pm25 is higher than 300 in cloudy conditions and with humidity
 * higher than 80%.
*/

-- Continuous version
WITH SelectedTripsTime(TripId, Time) AS (
  SELECT TripId,
    unnest(spans(whenTrue(Pm25 #> 300) * whenTrue(tfloat(Weather,
    'CloudCover', 'step') #> 0) *
    whenTrue(tfloat(Weather, 'Humidity', 'step') #> 80)))
      FROM Trips
  WHERE whenTrue(Pm25 #> 300) IS NOT NULL
    AND whenTrue(tfloat(Weather, 'CloudCover',
    'step') #> 0) IS NOT NULL AND
    whenTrue(tfloat(Weather, 'Humidity',
      'step') #> 80) IS NOT NULL )
SELECT d.TripId, atTime(d.Pm25, t.Time) AS Pm25, t.Time,
  duration(t.time) AS Duration
FROM Trips d, SelectedTripsTime t WHERE d.TripId = t.TripId
  AND duration(Time) >= '30 minutes' ORDER BY TripId, Time;
