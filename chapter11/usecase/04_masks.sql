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

-- Section "Fixing the Questions Before the Answers" of the use case of chapter 11: the positions
-- that every model is asked to reconstruct, fixed once, before any model is run. Recovery masks
-- about half of the observed positions of each window, selected by a hash of their key;
-- prediction masks the last observed positions before each gap, up to 10 positions or 15% of
-- them, in the windows with at least two positions before the gap, so that one stays visible.
-- Then the view ModelInput assembles the sequences given to the model, one per window and task,
-- withholding the coordinates, kinematics, and embedded description (PointEmbedding,
-- written by embed.py) of every masked position.
--
--   psql -d ais -f 04_masks.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS EvalMasks CASCADE;
CREATE TABLE EvalMasks AS
SELECT GapId, PointIdx, 'recovery' AS Task
FROM TripPoints
WHERE NOT InGap AND abs(hashtext(format('%s/%s', GapId, PointIdx))) % 100 < 50;
INSERT INTO EvalMasks
SELECT GapId, PointIdx, 'prediction'
FROM ( SELECT p.GapId, p.PointIdx,
         COUNT(*) OVER (PARTITION BY p.GapId) AS N,
         row_number() OVER (PARTITION BY p.GapId
           ORDER BY p.PointIdx DESC) AS K
       FROM TripPoints p JOIN Gaps g USING (GapId)
       WHERE p.T <= g.TStart ) AS q
WHERE N >= 2 AND K <= least(10, ceil(0.15 * N));
ALTER TABLE EvalMasks ADD PRIMARY KEY (Task, GapId, PointIdx);

-- Without embed.py, PointEmbedding is empty, and only the model that reconstructs from positions
-- and times is run (run_model.py).
CREATE TABLE IF NOT EXISTS PointEmbedding(GapId bigint, PointIdx bigint, Emb real[],
  PRIMARY KEY (GapId, PointIdx));

-- The local time zone of a window is the one of its first observed position, so that every
-- position of the window, the masked ones included, has a day and an hour in local time, as the
-- temporal channel of the model expects.
CREATE OR REPLACE VIEW ModelInput AS
WITH Tasks AS (
  SELECT 'recovery' AS Task, p.GapId, p.PointIdx, p.T,
    p.InGap OR m.PointIdx IS NOT NULL AS Masked
  FROM TripPoints p LEFT JOIN EvalMasks m ON m.Task = 'recovery' AND
    m.GapId = p.GapId AND m.PointIdx = p.PointIdx
  UNION ALL
  SELECT 'prediction', p.GapId, p.PointIdx, p.T, p.InGap OR m.PointIdx IS NOT NULL
  FROM TripPoints p JOIN Gaps g ON g.GapId = p.GapId
    LEFT JOIN EvalMasks m ON m.Task = 'prediction' AND
      m.GapId = p.GapId AND m.PointIdx = p.PointIdx
  WHERE p.T <= g.TStart
  UNION ALL
  SELECT 'gap', p.GapId, p.PointIdx, p.T, p.InGap
  FROM TripPoints p ),
WindowZone AS (
  SELECT DISTINCT ON (GapId) GapId, CASE EEZ
      WHEN 'DNK' THEN 'Europe/Copenhagen' WHEN 'SWE' THEN 'Europe/Stockholm'
      WHEN 'NOR' THEN 'Europe/Oslo' WHEN 'DEU' THEN 'Europe/Berlin'
      WHEN 'POL' THEN 'Europe/Warsaw' WHEN 'NLD' THEN 'Europe/Amsterdam'
      WHEN 'GBR' THEN 'Europe/London' WHEN 'RUS' THEN 'Europe/Moscow'
      ELSE 'UTC' END AS Zone
  FROM PointContext ORDER BY GapId, PointIdx )
SELECT t.Task, t.GapId, t.PointIdx, extract(epoch FROM t.T) AS Ts,
  extract(isodow FROM t.T AT TIME ZONE z.Zone)::int - 1 AS Dow,
  extract(hour FROM t.T AT TIME ZONE z.Zone)::int AS Hour,
  extract(minute FROM t.T)::int AS Minute, t.Masked,
  CASE WHEN NOT t.Masked THEN ST_X(c.GeomLonLat) END AS Lon,
  CASE WHEN NOT t.Masked THEN ST_Y(c.GeomLonLat) END AS Lat,
  CASE WHEN NOT t.Masked THEN c.SOG END AS SOG,
  CASE WHEN NOT t.Masked THEN c.COG END AS COG,
  CASE WHEN NOT t.Masked THEN c.ROT END AS ROT,
  CASE WHEN NOT t.Masked THEN e.Emb END AS Emb
FROM Tasks t JOIN WindowZone z USING (GapId)
  LEFT JOIN PointContext c ON c.GapId = t.GapId AND c.PointIdx = t.PointIdx
  LEFT JOIN PointEmbedding e ON e.GapId = t.GapId AND e.PointIdx = t.PointIdx;

SELECT Task, COUNT(*) AS Positions, COUNT(DISTINCT GapId) AS Windows
FROM EvalMasks GROUP BY Task ORDER BY Task;
