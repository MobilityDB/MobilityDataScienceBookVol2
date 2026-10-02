-- The table Segments: the stops and moves of each piece of AISClean, under the rules of the
-- MobilityLakehouse pipeline (benchmark/planar/20_clean.sql and 25_segments.sql of
-- https://github.com/MobilityDB/MobilityLakehouse):
--   speed    the speed of a report is the speed of the centroid of the positions over
--            [t, t + 600 s], or over [t - 600 s, t] where the first window spans under 300 s, and
--            the reported speed over ground where neither spans 300 s, in knots;
--   stops    a vessel becomes stopped at <= 0.2 kn and moving again at >= 0.5 kn, keeping its
--            state in between; a stopped run lasting at least 300 s is a stop;
--   segments every stop is a stationary segment; the moves are the stretches before the first
--            stop, between two stops and after the last one, each closed at both ends, so
--            consecutive segments share one report; a piece with no stop is one move.
-- A segment carries its trajectory in EPSG:25832 in Trip and in longitude and latitude in
-- TripLonLat.
--
--   psql -d ais -f ais_segments.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

-- The speed of each report, in knots.
CREATE TEMP TABLE Speed AS
SELECT MMSI, Piece, T, Ts,
  coalesce(
    CASE WHEN TfMax - Ts >= 300 THEN sqrt((Xf - X) ^ 2 + (Yf - Y) ^ 2) / (Tf - Ts)
         WHEN Ts - TbMin >= 300 THEN sqrt((X - Xb) ^ 2 + (Y - Yb) ^ 2) / (Ts - Tb) END
      * 3600 / 1852,
    SOG) AS V
FROM (
  SELECT *,
    avg(X) OVER Fw AS Xf, avg(Y) OVER Fw AS Yf, avg(Ts) OVER Fw AS Tf, max(Ts) OVER Fw AS TfMax,
    avg(X) OVER Bw AS Xb, avg(Y) OVER Bw AS Yb, avg(Ts) OVER Bw AS Tb, min(Ts) OVER Bw AS TbMin
  FROM (
    SELECT MMSI, Piece, T, EXTRACT(EPOCH FROM T)::float8 AS Ts, ST_X(Geom) AS X, ST_Y(Geom) AS Y,
      SOG
    FROM AISClean) C
  WINDOW Fw AS (PARTITION BY MMSI, Piece ORDER BY T
                RANGE BETWEEN CURRENT ROW AND interval '600 s' FOLLOWING),
         Bw AS (PARTITION BY MMSI, Piece ORDER BY T
                RANGE BETWEEN interval '600 s' PRECEDING AND CURRENT ROW)) S;

-- The hysteresis, and the stopped runs lasting at least 300 s.
CREATE TEMP TABLE StopRun AS
WITH Mk AS (
  SELECT *, CASE WHEN V <= 0.2 THEN true WHEN V >= 0.5 THEN false END AS Mark FROM Speed),
G AS (SELECT *, count(Mark) OVER (PARTITION BY MMSI, Piece ORDER BY T) AS Grp FROM Mk),
St AS (
  SELECT *, coalesce(first_value(Mark) OVER (PARTITION BY MMSI, Piece, Grp ORDER BY T), false)
    AS Still
  FROM G),
I AS (
  SELECT *, sum(CASE WHEN Still IS DISTINCT FROM PrevStill THEN 1 ELSE 0 END)
    OVER (PARTITION BY MMSI, Piece ORDER BY T) AS Run
  FROM (SELECT *, lag(Still) OVER (PARTITION BY MMSI, Piece ORDER BY T) AS PrevStill FROM St) L)
SELECT MMSI, Piece, min(T) AS TStart, max(T) AS TEnd, count(*) AS NoPoints
FROM I WHERE Still GROUP BY MMSI, Piece, Run
HAVING EXTRACT(EPOCH FROM max(T) - min(T)) >= 300;

-- The time interval of every segment.
CREATE TEMP TABLE SegInterval AS
WITH P AS (SELECT MMSI, Piece, min(T) AS P0, max(T) AS P1 FROM AISClean GROUP BY MMSI, Piece),
S AS (
  SELECT R.*, lag(TEnd) OVER W AS PrevEnd, lead(TStart) OVER W AS NextStart
  FROM StopRun R WINDOW W AS (PARTITION BY MMSI, Piece ORDER BY TStart))
SELECT MMSI, Piece, 'Stationary' AS SegmentType, TStart AS T0, TEnd AS T1 FROM S
UNION ALL
SELECT S.MMSI, S.Piece, 'In motion', coalesce(S.PrevEnd, P.P0), S.TStart
FROM S JOIN P USING (MMSI, Piece) WHERE coalesce(S.PrevEnd, P.P0) < S.TStart
UNION ALL
SELECT S.MMSI, S.Piece, 'In motion', S.TEnd, P.P1
FROM S JOIN P USING (MMSI, Piece) WHERE S.NextStart IS NULL AND S.TEnd < P.P1
UNION ALL
SELECT P.MMSI, P.Piece, 'In motion', P.P0, P.P1
FROM P WHERE NOT EXISTS (
  SELECT 1 FROM StopRun R WHERE R.MMSI = P.MMSI AND R.Piece = P.Piece);

DROP TABLE IF EXISTS Segments CASCADE;
CREATE TABLE Segments AS
SELECT I.MMSI, I.Piece, I.SegmentType, I.T0 AS TStart, I.T1 AS TEnd, count(*) AS NoPoints,
  mode() WITHIN GROUP (ORDER BY C.ShipType COLLATE "C") AS ShipType,
  tgeompointSeq(array_agg(tgeompoint(C.Geom, C.T) ORDER BY C.T)) AS Trip,
  tgeompointSeq(array_agg(tgeompoint(ST_Point(C.Longitude, C.Latitude, 4326), C.T) ORDER BY C.T))
    AS TripLonLat
FROM SegInterval I
JOIN AISClean C ON C.MMSI = I.MMSI AND C.Piece = I.Piece AND C.T BETWEEN I.T0 AND I.T1
GROUP BY I.MMSI, I.Piece, I.SegmentType, I.T0, I.T1;
CREATE INDEX ON Segments (MMSI, TStart);
ANALYZE Segments;

SELECT SegmentType, count(*) AS Segments, count(DISTINCT MMSI) AS Vessels
FROM Segments GROUP BY SegmentType ORDER BY SegmentType;
