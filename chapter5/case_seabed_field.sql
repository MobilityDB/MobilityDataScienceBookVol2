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

-- Case Study: Seabed Surveys as Observed Fields. The two multibeam survey
-- lines off Rostock that ../chapter3/soundings/load_soundings.sql loads into
-- the AIS database of the book (Swaths, one temporal patch per line, and
-- SurveyArea, the area the surveys cover), related to the vessels of the AIS
-- day (Ships and Vessels of ../ais/build.sh). The square of 10 m is centered
-- where the two lines cross. Every table is in EPSG:25832, so no query
-- transforms a geometry.
SET TimeZone = 'UTC';
SET client_min_messages = warning;
\pset footer off

\echo == Query: the vessels of the AIS day that came within 1 km of the surveyed area (32)
SELECT COUNT(*) AS Vessels
FROM Ships s, SurveyArea a
WHERE eDwithin(s.Trip, a.Geom, 1000);
SELECT s.MMSI, v.ShipType, v.Length,
  round(nearestApproachDistance(s.Trip, a.Geom)) AS MinDist,
  duration(whenTrue(tDwithin(s.Trip, a.Geom, 1000))) AS Within1km
FROM Ships s JOIN Vessels v USING (MMSI), SurveyArea a
WHERE eDwithin(s.Trip, a.Geom, 1000)
ORDER BY MinDist LIMIT 5;

\echo == Text: 27 of the 32 vessels came at 700 to 850 m of the surveyed area
SELECT COUNT(*) FILTER (WHERE MinDist BETWEEN 700 AND 850) AS At700to850,
  COUNT(*) AS Vessels
FROM (SELECT nearestApproachDistance(s.Trip, a.Geom) AS MinDist
  FROM Ships s, SurveyArea a
  WHERE eDwithin(s.Trip, a.Geom, 1000)) t;

\echo == Query: topography and amplitude of the soundings in the square, by survey
\echo == (-5.266 | 0.051 | 5072, -5.061 | 0.059 | 3636)
SELECT Line, round(AVG(getZ(p.Point)), 3) AS MeanZ,
  round(STDDEV(getZ(p.Point)), 3) AS StdDevZ,
  round(AVG(getDim(p.Point, 'Amplitude'))) AS MeanAmplitude
FROM Swaths, points(atGeometry(Swath,
  ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832))) p
GROUP BY Line ORDER BY Line;
