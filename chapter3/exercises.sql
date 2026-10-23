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

-- Exercises of the chapter Temporal Geometries and Temporal Circular Buffers on
-- the AIS database of the book, after ships_noise.sql has added the column Noise
-- to the table Ships and tcbuffer_case_study.sql has built the table Exposure.
-- The comment under each query is the answer it gives.
--   psql -d ais -f exercises.sql
\pset footer off
SET TimeZone = 'UTC';

-- Exercise 1: the database of the case study

\echo == 1.1 largest radius of the noise of the fishing vessel, and when
SELECT round(maxValue(Noise::tfloat)::numeric) AS MaxRadius,
  startTimestamp(atMax(Noise::tfloat)) AS AtTime
FROM Ships
WHERE MMSI = 220323000;
-- 3891 | 2026-01-20 16:48:13+00

\echo == 1.2 protected areas reached for the longest time by the noise of the passenger vessel
SELECT n.Id, n.NameEng,
  duration(whenTrue(tIntersects(v.Noise, n.Geom))) AS Duration
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 219000407 AND v.Noise && stbox(n.Geom)
  AND eIntersects(n.Geom, v.Noise)
ORDER BY 3 DESC
LIMIT 3;
-- 70  | U                           | 07:21:02.112344
-- 14  | Havet omkring Nordre Rønner | 07:07:23.342239
-- 129 | N                           | 07:05:57.769052

\echo == 1.3 vessels whose noise reaches area 14 while their trajectory does not enter it
SELECT COUNT(*) AS Vessels
FROM Ships v, NaturalAreas n
WHERE n.Id = 14 AND v.Noise && stbox(n.Geom)
  AND eIntersects(n.Geom, v.Noise) AND NOT eIntersects(n.Geom, v.Trip);
-- 22

\echo == 1.4 periods in which the two vessels of the case study are within 10 km
SELECT numSpans(whenTrue(tDwithin(a.Noise, b.Noise, 10000))) AS Periods,
  duration(whenTrue(tDwithin(a.Noise, b.Noise, 10000))) AS Duration
FROM Ships a, Ships b
WHERE a.MMSI = 220323000 AND b.MMSI = 219000407;
-- 2 | 00:10:52.414055

\echo == 1.5 area swept by a circular buffer of radius 1 moving 10 units
SELECT round(ST_Area(traversedArea(tcbuffer(
  tgeompoint '[Point(0 0)@2001-01-01, Point(10 0)@2001-01-02]',
  tfloat '[1@2001-01-01, 1@2001-01-02]'), true))::numeric, 2) AS Area;
-- 23.14

-- Exercise 2: temporal circular buffers of literal values

\echo == 2.1 radius and area halfway through a growing buffer
WITH T(Tcb) AS (
  SELECT tcbuffer '[Cbuffer(Point(0 0), 1)@2001-01-01,
    Cbuffer(Point(0 0), 3)@2001-01-03]' )
SELECT round(radius(valueAtTimestamp(Tcb, '2001-01-02'))::numeric, 2) AS Radius,
  round(ST_Area(geometry(valueAtTimestamp(Tcb, '2001-01-02')))::numeric, 4)
    AS Area
FROM T;
-- 2.00 | 12.5611

\echo == 2.2 temporal distance of a moving buffer to a point, with its turning point
SELECT round(tcbuffer '[Cbuffer(Point(0 0), 1)@2001-01-01,
  Cbuffer(Point(10 0), 1)@2001-01-02]' <-> geometry 'Point(5 3)', 3);
-- [4.831@2001-01-01 00:00:00+00, 2@2001-01-01 12:00:00+00,
--  4.831@2001-01-02 00:00:00+00]

\echo == 2.3 period in which a moving and a static buffer are within a distance of 3
WITH T(Tcb, Cb) AS (
  SELECT tcbuffer '[Cbuffer(Point(0 0), 1)@2001-01-01,
    Cbuffer(Point(10 0), 1)@2001-01-02]', cbuffer 'Cbuffer(Point(5 4), 1)' )
SELECT whenTrue(tDwithin(Tcb, Cb, 3)) AS Periods,
  eDwithin(Tcb, Cb, 3) AS EverWithin, aDwithin(Tcb, Cb, 3) AS AlwaysWithin
FROM T;
-- {[2001-01-01 04:48:00+00, 2001-01-01 19:12:00+00]} | t | f

\echo == 2.4 traversed area of a buffer that stays inside its last value
WITH T(Area) AS (
  SELECT traversedArea(tcbuffer '[Cbuffer(Point(0 0), 1)@2001-01-01,
    Cbuffer(Point(1 0), 3)@2001-01-02]', true) )
SELECT ST_AsText(Area), round(ST_Area(Area)::numeric, 4) AS Area
FROM T;
-- CURVEPOLYGON(CIRCULARSTRING(-2 0,4 0,-2 0)) | 28.2624

-- Exercise 4: the table Exposure and the table Vessels

\echo == 4.1 average radius of the noise of the fishing vessel, in transit and fishing
SELECT
  round(twAvg(atTime(Noise::tfloat, whenTrue(SOG #> 6.0)))::numeric) AS Transit,
  round(twAvg(atTime(Noise::tfloat, whenTrue(SOG #<= 6.0)))::numeric) AS Fishing
FROM Ships
WHERE MMSI = 220323000;
-- 1923 | 187

\echo == 4.2 vessels whose noise reaches the most marine and coastal protected areas
SELECT e.MMSI, s.Name, s.ShipType, COUNT(*) AS Areas
FROM Exposure e JOIN Vessels s USING (MMSI)
GROUP BY e.MMSI, s.Name, s.ShipType
ORDER BY Areas DESC, e.MMSI LIMIT 3;
-- 636025443 | CAPRI  | Tanker  | 29
-- 219030383 | TOR-ON | Fishing | 28
-- 265019000 | AHLMA  | Fishing | 26
