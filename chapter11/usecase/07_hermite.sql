-- Section "Measuring the Reconstruction Error" of the use case of chapter 11, the stronger baseline:
-- the positions inside every gap reconstructed as the model 'hermite' by the cubic Hermite curve
-- between the two reports that bound the gap, whose tangents are the reported speed along the
-- reported course, the course turned into a direction of the grid of EPSG:25832 by projecting the
-- point 1 km along it on the ellipsoid; below 3 knots at either end, or without a course, the
-- positions lie on the straight segment, as in the baseline linear. The query then counts the gaps
-- in which the curve is used, and those in which it departs from the straight segment by more than
-- 100 m and 500 m.
--
--   psql -d ais -f 07_hermite.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DELETE FROM Reconstructed WHERE Model = 'hermite';

INSERT INTO Reconstructed
WITH Ends AS (
  SELECT g.GapId, g.TStart, g.PStart, g.PEnd,
    extract(epoch FROM g.TEnd - g.TStart) AS Dur,
    valueAtTimestamp(s.SOG, g.TStart) AS KStart,
    valueAtTimestamp(s.SOG, g.TEnd) AS KEnd,
    ST_Azimuth(g.PStart, ST_Transform(ST_Project(ST_Transform(g.PStart,
      4326)::geography, 1000,
      radians(valueAtTimestamp(s.COG, g.TStart)))::geometry, 25832)) AS AStart,
    ST_Azimuth(g.PEnd, ST_Transform(ST_Project(ST_Transform(g.PEnd,
      4326)::geography, 1000,
      radians(valueAtTimestamp(s.COG, g.TEnd)))::geometry, 25832)) AS AEnd
  FROM Gaps g JOIN Ships s USING (MMSI) ),
Steps AS (
  SELECT e.*, p.PointIdx,
    extract(epoch FROM p.T - e.TStart) / e.Dur AS s,
    e.Dur * e.KStart * 1852 / 3600 AS LStart,
    e.Dur * e.KEnd * 1852 / 3600 AS LEnd
  FROM Ends e JOIN TripPoints p USING (GapId)
  WHERE p.InGap )
SELECT 'hermite', 'gap', GapId, PointIdx,
  CASE WHEN KStart >= 3 AND KEnd >= 3 AND AStart IS NOT NULL
    AND AEnd IS NOT NULL
  THEN ST_SetSRID(ST_MakePoint(
    (2*s^3 - 3*s^2 + 1) * ST_X(PStart)
      + (s^3 - 2*s^2 + s) * LStart * sin(AStart)
      + (-2*s^3 + 3*s^2) * ST_X(PEnd) + (s^3 - s^2) * LEnd * sin(AEnd),
    (2*s^3 - 3*s^2 + 1) * ST_Y(PStart)
      + (s^3 - 2*s^2 + s) * LStart * cos(AStart)
      + (-2*s^3 + 3*s^2) * ST_Y(PEnd) + (s^3 - s^2) * LEnd * cos(AEnd)),
    25832)
  ELSE ST_LineInterpolatePoint(ST_MakeLine(PStart, PEnd), s) END
FROM Steps;

\echo The gaps in which the curve departs from the straight segment, and by how much (meters)
WITH PerGap AS (
  SELECT r.GapId, MAX(ST_Distance(r.Geom, ST_LineInterpolatePoint(ST_MakeLine(g.PStart, g.PEnd),
    extract(epoch FROM p.T - g.TStart) / extract(epoch FROM g.TEnd - g.TStart)))) AS Sep
  FROM Reconstructed r JOIN TripPoints p USING (GapId, PointIdx) JOIN Gaps g USING (GapId)
  WHERE r.Model = 'hermite' AND r.Task = 'gap'
  GROUP BY r.GapId )
SELECT COUNT(*) AS Gaps, COUNT(*) FILTER (WHERE Sep > 0) AS Curved,
  COUNT(*) FILTER (WHERE Sep > 100) AS Over100, COUNT(*) FILTER (WHERE Sep > 500) AS Over500
FROM PerGap;
