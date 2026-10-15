WITH Timespan(Period) AS (
 SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
 SELECT MMSI, atTime(s.Trip, t.Period)
 FROM Ships s TABLESAMPLE RESERVOIR (NSAMPLE ROWS) REPEATABLE (1),
   Timespan t
 WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
TimeClosestShips(MMSI1, MMSI2, ClosestDist, TimeAtClosestDist, Trip1, Trip2) AS (
 SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)),
  startTimestamp(atMin(s1.Trip <-> s2.Trip)), s1.Trip, s2.Trip
 FROM TimeShips s1, TimeShips s2
 WHERE s1.MMSI < s2.MMSI AND CASE WHEN eDwithin(s1.Trip, s2.Trip, 300)
  THEN startValue(atMin(s1.Trip <-> s2.Trip)) < 300 END )
SELECT t.MMSI1, t.MMSI2, t.ClosestDist, t.TimeAtClosestDist,
 valueAtTimestamp(Trip1, TimeAtClosestDist) AS Point1,
 valueAtTimestamp(Trip2, TimeAtClosestDist) AS Point2
FROM TimeClosestShips t;
