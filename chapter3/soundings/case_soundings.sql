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

-- Use Case: Seabed Surveys. The two survey lines that load_soundings.sql
-- loads, as one patch per ping (Pings), one temporal patch per line (Swaths),
-- and the trip of the survey vessel along each line (Tracks), in the order of
-- the section. The vessel is a circle of 3.75 m as a temporal circular buffer,
-- and the pentagon of 7.5 m by 2.55 m centered on its antenna as a temporal
-- rigid geometry. The square of 10 m is centered where the two lines cross.
-- Every table is in EPSG:25832, so no query transforms a geometry. The \echo
-- before each listing states the answer the book prints.
--
--   psql -d soundings -f case_soundings.sql
SET TimeZone = 'UTC';
SET client_min_messages = warning;
\pset footer off

\echo == Listing: the survey lines as temporal patches and as trips
\echo == (4851 | 2390742 | 00:04:54.548153 | 541, 3358 | 1643152 | 00:02:29.037577 | 290)
SELECT s.Line, numInstants(s.Swath) AS Pings, numPoints(s.Swath) AS Soundings,
  duration(s.Swath, true) AS Duration, round(length(t.Trip)) AS Meters
FROM Swaths s JOIN Tracks t ON t.Line = s.Line
ORDER BY s.Line;

\echo == Text: about 490 soundings per ping, about 16 pings per second in May and 23 in October
SELECT Line, round(numPoints(Swath)::numeric / numInstants(Swath)) AS SoundingsPerPing,
  round(numInstants(Swath) / extract(epoch FROM duration(Swath, true)), 1)
    AS PingsPerSecond
FROM Swaths
ORDER BY Line;

\echo == Text: the azimuth of the October line lies between 5.12 and 5.58 radians
SELECT round(minValue(azimuth(Trip))::numeric, 2) AS MinAzimuth,
  round(maxValue(azimuth(Trip))::numeric, 2) AS MaxAzimuth
FROM Tracks
WHERE Line = '20191022_085450_kh1910_400khz';

\echo == Query: which part of the seabed did the vessel cover along the October line,
\echo == and which part did its pings sound (1643152 | 2217 | 810 | 12931)
SELECT ST_NPoints(traversedArea(tgeometry(s.Swath))) AS Soundings,
  round(ST_Area(traversedArea(tcbuffer(t.Trip, tfloat(3.75, timeSpan(t.Trip))),
    true))) AS Buffer,
  round(ST_Area(traversedArea(trgeometry(
    geometry 'SRID=25832;Polygon((-3.75 -1.275,1.875 -1.275,3.75 0,
      1.875 1.275,-3.75 1.275,-3.75 -1.275))',
    tpose(t.Trip, 5 * pi() / 2 - azimuth(t.Trip))), true))) AS Vessel,
  round(ST_Area(swath(s.Swath))) AS SwathArea
FROM Swaths s JOIN Tracks t USING (Line)
WHERE Line = '20191022_085450_kh1910_400khz';

\echo == Listing: the same areas over the ten seconds from 08:54:50 to 08:55:00 (190 | 69 | 797)
SELECT round(ST_Area(traversedArea(tcbuffer(t.Trip, tfloat(3.75, timeSpan(t.Trip))),
    true))) AS Buffer,
  round(ST_Area(traversedArea(trgeometry(
    geometry 'SRID=25832;Polygon((-3.75 -1.275,1.875 -1.275,3.75 0,
      1.875 1.275,-3.75 1.275,-3.75 -1.275))',
    tpose(t.Trip, 5 * pi() / 2 - azimuth(t.Trip))), true))) AS Vessel,
  round(ST_Area(swath(s.Swath))) AS SwathArea
FROM (SELECT Line, atTime(Swath, tstzspan '[2019-10-22 08:54:50+00,
    2019-10-22 08:55:00+00]') AS Swath FROM Swaths) s
  JOIN (SELECT Line, atTime(Trip, tstzspan '[2019-10-22 08:54:50+00,
    2019-10-22 08:55:00+00]') AS Trip FROM Tracks) t USING (Line)
WHERE Line = '20191022_085450_kh1910_400khz';

\echo == Query: when was the square sounded, by how many pings and soundings, pgPointCloud
\echo == (103 | 25812, 173 | 37002)
WITH Sounded AS (
  SELECT Line, T, PC_FilterBetween(PC_FilterBetween(Patch, 'X', 702990, 703000),
    'Y', 6008572, 6008582) AS Patch
  FROM Pings )
SELECT Line, COUNT(*) AS Pings, SUM(PC_NumPoints(Patch)) AS Soundings,
  MIN(T) AS FirstPing, MAX(T) AS LastPing
FROM Sounded
WHERE PC_NumPoints(Patch) > 0
GROUP BY Line ORDER BY Line;

\echo == Query: when was the square sounded, by how many pings and soundings, MobilityDB
\echo == (103 | 25812, 173 | 37002)
SELECT Line, numInstants(Sq) AS Pings, numPoints(Sq) AS Soundings,
  timeSpan(Sq) AS Period
FROM Swaths, LATERAL (SELECT atGeometry(Swath,
  ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832)) AS Sq) s
ORDER BY Line;

\echo == Text: the pings whose box meets the square, kept whole (162 | 80264, 590 | 289867)
SELECT Line, numInstants(Sq) AS Pings, numPoints(Sq) AS Soundings
FROM Swaths, LATERAL (SELECT atTpcbox(Swath,
  tpcbox 'SRID=25832;TPCBOX(X((702990,6008572),(703000,6008582)), 1)') AS Sq) s
ORDER BY Line;

\echo == Query: speed of the vessel while it sounded the square, and spacing of its pings
\echo == (3.72 | 11.2 | 0.11, 3.77 | 14 | 0.081)
WITH Sounded AS (
  SELECT Line, atGeometry(Swath,
    ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832)) AS Sq
  FROM Swaths )
SELECT t.Line,
  round(twAvg(speed(atTime(t.Trip, timeSpan(s.Sq)))) * 3600 / 1852, 2) AS Knots,
  round(length(atTime(t.Trip, timeSpan(s.Sq))), 1) AS Meters,
  round(length(atTime(t.Trip, timeSpan(s.Sq))) / (numInstants(s.Sq) - 1), 3)
    AS MetersPerPing
FROM Tracks t JOIN Sounded s ON s.Line = t.Line
ORDER BY t.Line;

\echo == Query: the most soundings a ping of each line put into the square (294, 349)
SELECT Line, maxValue(tnpoints(atGeometry(Swath,
  ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832)))) AS MaxPerPing
FROM Swaths
GROUP BY Line ORDER BY Line;

\echo == Query: topography and amplitude of the soundings in the square, by survey
\echo == (-5.266 | 0.051 | 5072, -5.061 | 0.059 | 3636)
SELECT Line, round(AVG(getZ(p.Point)), 3) AS MeanZ,
  round(STDDEV(getZ(p.Point)), 3) AS StdDevZ,
  round(AVG(getDim(p.Point, 'Amplitude'))) AS MeanAmplitude
FROM Swaths, points(atGeometry(Swath,
  ST_MakeEnvelope(702990, 6008572, 703000, 6008582, 25832))) p
GROUP BY Line ORDER BY Line;
