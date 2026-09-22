-- Section 8: vessel-hours per H3 cell of resolution 5, computed from the
-- temporal cells at resolution 5 and rolled up from the cells at resolution 7.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS CellTraffic5;
CREATE TABLE CellTraffic5 AS
SELECT u.value AS Cell, count(DISTINCT s.MMSI) AS Vessels,
  sum(duration(u.time)) AS VesselTime
FROM Ships s, unnest(th3index(s.TripLonLat, 5)) AS u
GROUP BY u.value;

\echo == direct against rolled up, per cell of resolution 5
WITH RollUp AS (
  SELECT cellToParent(Cell, 5) AS Cell, sum(VesselTime) AS VesselTime,
    sum(Vessels) AS VesselsSum
  FROM CellTraffic
  GROUP BY 1 )
SELECT count(*) AS Cells,
  count(*) FILTER (WHERE r.Cell IS NULL OR d.Cell IS NULL) AS OnlyOneSide,
  count(*) FILTER (WHERE abs(EXTRACT(EPOCH FROM d.VesselTime - r.VesselTime)) >
    0.05 * EXTRACT(EPOCH FROM d.VesselTime)) AS Differ5Pct,
  count(*) FILTER (WHERE r.VesselsSum > d.Vessels) AS VesselsOvercount,
  round(EXTRACT(EPOCH FROM sum(d.VesselTime)) / 3600) AS DirectHours,
  round(EXTRACT(EPOCH FROM sum(r.VesselTime)) / 3600) AS RolledHours
FROM CellTraffic5 d FULL JOIN RollUp r USING (Cell);

\echo == the largest differences
WITH RollUp AS (
  SELECT cellToParent(Cell, 5) AS Cell, sum(VesselTime) AS VesselTime
  FROM CellTraffic
  GROUP BY 1 )
SELECT Cell, round(EXTRACT(EPOCH FROM d.VesselTime) / 3600, 1) AS DirectHours,
  round(EXTRACT(EPOCH FROM r.VesselTime) / 3600, 1) AS RolledHours
FROM CellTraffic5 d JOIN RollUp r USING (Cell)
ORDER BY abs(EXTRACT(EPOCH FROM d.VesselTime - r.VesselTime)) DESC
LIMIT 5;
