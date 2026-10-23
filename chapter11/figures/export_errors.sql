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

-- The data of the figures of the errors of the use case of chapter 11, read by curves.py and
-- fig_errors.py, for the models crossdomain and coordinates and the baseline linear: the mean error
-- of each model, task, and window (perwindow.csv); the mean speed of the vessel in each window, in
-- knots, from its visible one-minute positions (winspeed.csv); the error of every position masked
-- for recovery with its isolation, the number of minutes to the nearest visible position
-- (isolation.csv), and of every position masked for prediction with its horizon, the number of
-- minutes after the last visible position (horizon.csv); and, for the gap 5452, the reports that
-- bound it and the distance the vessel covers during it at 30 knots (q14_gap.csv), its positions
-- with the reconstruction of crossdomain inside the gap (q14_path.csv), and the protected areas
-- within that distance of its first report (q14_areas.csv).
--
--   psql -d ais -f export_errors.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

\copy (SELECT Model, Task, GapId, AVG(Err) AS Err FROM Errors WHERE Model IN ('linear', 'coordinates', 'crossdomain') GROUP BY Model, Task, GapId ORDER BY Task, GapId, Model) TO 'perwindow.csv' CSV HEADER

\copy (SELECT GapId, (SUM(d) / nullif(SUM(dt), 0)) * 1.9438445 AS Kn FROM ( SELECT GapId, ST_Distance(Geom, lag(Geom) OVER w) AS d, extract(epoch FROM T - lag(T) OVER w) AS dt FROM TripPoints WHERE NOT InGap WINDOW w AS (PARTITION BY GapId ORDER BY T) ) x GROUP BY GapId ORDER BY GapId) TO 'winspeed.csv' CSV HEADER

CREATE TEMP TABLE Isolation AS
WITH Visible AS (
  SELECT p.GapId, p.PointIdx
  FROM TripPoints p
  WHERE NOT p.InGap AND NOT EXISTS (
    SELECT 1 FROM EvalMasks m WHERE m.Task = 'recovery' AND
      m.GapId = p.GapId AND m.PointIdx = p.PointIdx ) )
SELECT m.GapId, m.PointIdx, MIN(abs(m.PointIdx - v.PointIdx)) AS Steps
FROM EvalMasks m JOIN Visible v USING (GapId)
WHERE m.Task = 'recovery'
GROUP BY m.GapId, m.PointIdx;
\copy (SELECT e.Model, i.Steps, e.GapId, e.Err FROM Errors e JOIN Isolation i USING (GapId, PointIdx) WHERE e.Task = 'recovery' AND e.Model IN ('linear', 'coordinates', 'crossdomain') ORDER BY e.GapId, e.Model, i.Steps, e.PointIdx) TO 'isolation.csv' CSV HEADER

CREATE TEMP TABLE Horizon AS
SELECT m.GapId, m.PointIdx, m.PointIdx - (
  SELECT MAX(i.PointIdx) FROM ModelInput i
  WHERE i.Task = 'prediction' AND i.GapId = m.GapId AND NOT i.Masked ) AS Horizon
FROM EvalMasks m
WHERE m.Task = 'prediction';
\copy (SELECT e.Model, h.Horizon, e.GapId, e.Err FROM Errors e JOIN Horizon h USING (GapId, PointIdx) WHERE e.Task = 'prediction' AND e.Model IN ('linear', 'coordinates', 'crossdomain') ORDER BY e.GapId, e.Model, h.Horizon) TO 'horizon.csv' CSV HEADER

\copy (SELECT ST_X(PStart), ST_Y(PStart), ST_X(PEnd), ST_Y(PEnd), 15.4 * extract(epoch FROM TEnd - TStart) FROM Gaps WHERE GapId = 5452) TO 'q14_gap.csv' CSV HEADER
\copy (SELECT p.PointIdx, p.InGap, ST_X(coalesce(r.Geom, p.Geom)), ST_Y(coalesce(r.Geom, p.Geom)) FROM TripPoints p LEFT JOIN Reconstructed r ON r.GapId = p.GapId AND r.PointIdx = p.PointIdx AND p.InGap AND r.Task = 'gap' AND r.Model = 'crossdomain' WHERE p.GapId = 5452 ORDER BY p.PointIdx) TO 'q14_path.csv' CSV HEADER
\copy (SELECT n.Id, n.NameEng, ST_AsText(n.Geom) FROM Gaps g JOIN NaturalAreas n ON ST_DWithin(n.Geom, g.PStart, 15.4 * extract(epoch FROM g.TEnd - g.TStart)) WHERE g.GapId = 5452 ORDER BY n.Id) TO 'q14_areas.csv' CSV HEADER
