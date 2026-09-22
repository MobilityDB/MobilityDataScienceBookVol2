-- Section 8: vessel-hours and distinct vessels per H3 cell of resolution 7
-- over the AIS day, from the temporal cells of the trips.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS CellTraffic;
CREATE TABLE CellTraffic AS
SELECT u.value AS Cell, count(DISTINCT s.MMSI) AS Vessels,
  sum(duration(u.time)) AS VesselTime
FROM Ships s, unnest(th3index(s.TripLonLat, 7)) AS u
GROUP BY u.value;

SELECT count(*) AS Cells, sum(Vessels) AS VesselCells,
  round(EXTRACT(EPOCH FROM sum(VesselTime)) / 3600) AS VesselHours
FROM CellTraffic;

\echo == the busiest cells by vessel-hours
SELECT Cell, Vessels, round(EXTRACT(EPOCH FROM VesselTime) / 3600, 1) AS VesselHours,
  round(ST_X(cellToPoint(Cell))::numeric, 3) AS Lon, round(ST_Y(cellToPoint(Cell))::numeric, 3) AS Lat
FROM CellTraffic
ORDER BY VesselTime DESC
LIMIT 10;
