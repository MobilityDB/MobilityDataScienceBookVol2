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

-- Section "What the Model Cannot Decide" of the use case of chapter 11: the reconstructed path of
-- every gap as a temporal point, and, for each gap and protected area, whether the vessel could
-- have entered the area during the gap at a speed of at most 30 knots, an exact answer that does
-- not depend on any model, beside whether the reconstructed path enters it.
--
--   psql -d ais -f 06_exact.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS GapPaths CASCADE;
CREATE TABLE GapPaths AS
SELECT g.GapId, g.MMSI, tgeompointSeq(array_agg(tgeompoint(x.Geom, x.T)
  ORDER BY x.T)) AS Path
FROM Gaps g, LATERAL (
  SELECT g.TStart AS T, g.PStart AS Geom
  UNION ALL
  SELECT p.T, r.Geom
  FROM TripPoints p JOIN Reconstructed r USING (GapId, PointIdx)
  WHERE p.GapId = g.GapId AND r.Task = 'gap' AND r.Model = 'crossdomain'
  UNION ALL
  SELECT g.TEnd, g.PEnd ) AS x
GROUP BY g.GapId, g.MMSI;
ALTER TABLE GapPaths ADD PRIMARY KEY (GapId);

DROP TABLE IF EXISTS GapAreas CASCADE;
CREATE TABLE GapAreas AS
WITH Bounds AS (
  SELECT GapId, PStart, PEnd,
    15.4 * extract(epoch FROM TEnd - TStart) AS Reach
  FROM Gaps )
SELECT b.GapId, n.NameEng,
  ST_DWithin(n.Geom, b.PStart, b.Reach) AND
    ST_DWithin(n.Geom, b.PEnd, b.Reach) AS Possible,
  eIntersects(p.Path, n.Geom) AS Reconstructed
FROM Bounds b JOIN GapPaths p USING (GapId), NaturalAreas n
WHERE ST_DWithin(n.Geom, b.PStart, b.Reach);

SELECT Possible, Reconstructed, COUNT(*) AS Pairs, COUNT(DISTINCT GapId) AS Gaps
FROM GapAreas
GROUP BY Possible, Reconstructed
ORDER BY Possible, Reconstructed;
