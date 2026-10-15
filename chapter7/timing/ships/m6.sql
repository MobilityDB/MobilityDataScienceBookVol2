WITH Timespan(Period) AS (
 SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
 SELECT MMSI, atTime(s.Trip, t.Period)
 FROM Ships s TABLESAMPLE RESERVOIR (NSAMPLE ROWS) REPEATABLE (1),
   Timespan t
 WHERE atTime(s.Trip, t.Period) IS NOT NULL )
SELECT s1.MMSI, s2.MMSI, s1.Trip, s2.Trip,
 ST_AsText(trajectory(s1.Trip)) as traj1,
 ST_AsText(trajectory(s2.Trip)) as traj2
FROM TimeShips s1, TimeShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300)  ;
