-- Section 8: a collection of RaQuet tiles that changes over time is read by
-- joining the tiles on the cells of the trip and on their validity period.
-- The bathymetry of sec8_raquet.sql has a single state, so its tiles are given
-- the two halves of the trip as their periods here: the reading over the tiles
-- of each period merges into the reading of the whole trip, which is the
-- property the section states.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS BathymetrySeries;
CREATE TABLE BathymetrySeries(Quadbin quadbin, Period tstzspan, Tile raquet);
INSERT INTO BathymetrySeries
SELECT quadbin(Tile), span(t.T1, t.T2, true, false), Tile
FROM BathymetryRaquet,
  (SELECT startTimestamp(Trip) AS T1,
     startTimestamp(Trip) + (duration(Trip) / 2) AS T2
   FROM Ships WHERE MMSI = 273277840) t;
INSERT INTO BathymetrySeries
SELECT quadbin(Tile), span(t.T2, t.T3, true, true), Tile
FROM BathymetryRaquet,
  (SELECT startTimestamp(Trip) + (duration(Trip) / 2) AS T2,
     endTimestamp(Trip) AS T3
   FROM Ships WHERE MMSI = 273277840) t;

\echo == the depth under the vessel read from the tiles of each period
SELECT numSpans(whenTrue(Depth #< 20)) AS Periods,
  duration(whenTrue(Depth #< 20)) AS Under20
FROM (
  SELECT mergeAgg(rasterTileValue(atTime(s.TripLonLat, q.Period), q.Tile)
      ORDER BY q.Period) AS Depth
  FROM Ships s, BathymetrySeries q, unnest(tquadbin(s.TripLonLat, 11)) c
  WHERE s.MMSI = 273277840 AND q.Quadbin = c.value AND q.Period && c.time
  GROUP BY s.MMSI ) x;
-- 10 | 00:11:04.276526
