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

-- Section "Measuring the Reconstruction Error" of the use case of chapter 11: the reconstructions
-- of run_model.py in the reference system of the database, a baseline computed by the database by
-- linear interpolation, the errors at the positions fixed in EvalMasks, the comparison of the
-- models window by window, and the recovery error as a function of the isolation of the masked
-- positions.
--
--   psql -d ais -f 05_evaluate.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS Reconstructed CASCADE;
CREATE TABLE Reconstructed AS
SELECT Model, Task, GapId, PointIdx,
  ST_Transform(ST_Point(Lon, Lat, 4326), 25832) AS Geom
FROM ReconstructedLonLat;
ALTER TABLE Reconstructed ADD PRIMARY KEY (Model, Task, GapId, PointIdx);

-- The baseline 'linear', computed by the database alone: a masked position is placed on the
-- segment between the visible positions before and after it, in proportion to the time elapsed,
-- or, when no visible position follows it, as in prediction, extrapolated at the velocity of the
-- last two visible positions.
CREATE TEMP TABLE TaskPoints AS
SELECT i.Task, i.GapId, i.PointIdx, p.T, i.Masked, p.Geom
FROM ModelInput i JOIN TripPoints p USING (GapId, PointIdx);
CREATE TEMP TABLE Visible AS SELECT * FROM TaskPoints WHERE NOT Masked;
CREATE INDEX ON Visible (Task, GapId, PointIdx);
ANALYZE Visible;
INSERT INTO Reconstructed
SELECT 'linear', s.Task, s.GapId, s.PointIdx,
  CASE
    WHEN b.T IS NOT NULL AND a.T IS NOT NULL THEN
      ST_LineInterpolatePoint(ST_MakeLine(a.Geom, b.Geom),
        extract(epoch FROM s.T - a.T) / extract(epoch FROM b.T - a.T))
    WHEN b.T IS NULL AND a2.T IS NOT NULL THEN
      ST_Translate(a.Geom,
        (ST_X(a.Geom) - ST_X(a2.Geom)) * extract(epoch FROM s.T - a.T) /
          extract(epoch FROM a.T - a2.T),
        (ST_Y(a.Geom) - ST_Y(a2.Geom)) * extract(epoch FROM s.T - a.T) /
          extract(epoch FROM a.T - a2.T))
    ELSE coalesce(a.Geom, b.Geom) END
FROM TaskPoints s
  LEFT JOIN LATERAL ( SELECT * FROM Visible v WHERE v.Task = s.Task AND v.GapId = s.GapId
    AND v.PointIdx < s.PointIdx ORDER BY v.PointIdx DESC LIMIT 1 ) a ON true
  LEFT JOIN LATERAL ( SELECT * FROM Visible v WHERE v.Task = s.Task AND v.GapId = s.GapId
    AND v.PointIdx < a.PointIdx ORDER BY v.PointIdx DESC LIMIT 1 ) a2 ON true
  LEFT JOIN LATERAL ( SELECT * FROM Visible v WHERE v.Task = s.Task AND v.GapId = s.GapId
    AND v.PointIdx > s.PointIdx ORDER BY v.PointIdx LIMIT 1 ) b ON true
WHERE s.Masked AND (a.T IS NOT NULL OR b.T IS NOT NULL);

CREATE VIEW Errors AS
SELECT r.Model, r.Task, r.GapId, r.PointIdx, ST_Distance(r.Geom, p.Geom) AS Err
FROM Reconstructed r JOIN EvalMasks m USING (Task, GapId, PointIdx)
  JOIN TripPoints p USING (GapId, PointIdx);

\echo The mean, median, and 90th percentile of the error of each model and task (meters)
SELECT Model, Task, COUNT(*) AS Positions, round(AVG(Err)) AS MeanErr,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY Err)) AS MedianErr,
  round(percentile_cont(0.9) WITHIN GROUP (ORDER BY Err)) AS P90Err
FROM Errors
GROUP BY Model, Task
ORDER BY Task, Model;

\echo The model compared window by window with the model without context and with the baseline
WITH PerWindow AS (
  SELECT Model, Task, GapId, AVG(Err) AS Err
  FROM Errors
  GROUP BY Model, Task, GapId )
SELECT b.Model AS Versus, a.Task, COUNT(*) AS Windows,
  round(AVG(a.Err - b.Err)) AS MeanDiff,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY a.Err - b.Err)) AS MedianDiff,
  round(AVG((a.Err < b.Err)::int), 3) AS ShareBetter
FROM PerWindow a JOIN PerWindow b USING (Task, GapId)
WHERE a.Model = 'crossdomain' AND b.Model IN ('coordinates', 'linear')
GROUP BY b.Model, a.Task
ORDER BY b.Model, a.Task;

\echo The median recovery error as a function of the isolation of the masked positions
WITH Visible AS (
  SELECT p.GapId, p.PointIdx
  FROM TripPoints p
  WHERE NOT p.InGap AND NOT EXISTS (
    SELECT 1 FROM EvalMasks m WHERE m.Task = 'recovery' AND
      m.GapId = p.GapId AND m.PointIdx = p.PointIdx ) ),
Isolation AS (
  SELECT m.GapId, m.PointIdx, MIN(abs(m.PointIdx - v.PointIdx)) AS Steps
  FROM EvalMasks m JOIN Visible v USING (GapId)
  WHERE m.Task = 'recovery'
  GROUP BY m.GapId, m.PointIdx )
SELECT e.Model, i.Steps, COUNT(*) AS Positions,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY e.Err)) AS MedianErr
FROM Errors e JOIN Isolation i USING (GapId, PointIdx)
WHERE e.Task = 'recovery'
GROUP BY e.Model, i.Steps
ORDER BY e.Model, i.Steps;
