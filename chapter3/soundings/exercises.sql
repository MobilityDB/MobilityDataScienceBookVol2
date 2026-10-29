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

-- Exercise 5 of the chapter: the tables Swaths and Tracks of the use case on
-- seabed surveys, which load_soundings.sql builds. The \echo before each query
-- states the answer the book prints, as in case_soundings.sql.
--
--   psql -d ais -f exercises.sql
SET TimeZone = 'UTC';
SET client_min_messages = warning;
\pset footer off

\echo == 5.1 mean width of the swath of each survey line (25102 | 541 | 46.4, 12931 | 290 | 44.6)
SELECT s.Line, round(ST_Area(swath(s.Swath))) AS SwathArea,
  round(length(t.Trip)) AS Meters,
  round((ST_Area(swath(s.Swath)) / length(t.Trip))::numeric, 1) AS MeanWidth
FROM Swaths s JOIN Tracks t USING (Line)
ORDER BY s.Line;

\echo == 5.2 ping of each survey line with the most soundings, and when it was emitted
\echo == (503 | 2019-05-14 10:42:30.07847+00, 502 | 2019-10-22 08:54:54.425476+00)
SELECT Line, maxValue(n) AS MaxSoundings, startTimestamp(atMax(n)) AS Ping
FROM (SELECT Line, tnpoints(Swath) AS n FROM Swaths GROUP BY Line) t
ORDER BY Line;

\echo == 5.3 share of the swath of each survey line within 10 m of the track (43.0, 44.8)
SELECT s.Line, round((100 * ST_Area(ST_Intersection(swath(s.Swath),
  ST_Buffer(trajectory(t.Trip), 10))) / ST_Area(swath(s.Swath)))::numeric, 1)
  AS PctNearTrack
FROM Swaths s JOIN Tracks t USING (Line)
ORDER BY s.Line;
