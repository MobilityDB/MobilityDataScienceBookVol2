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

-- Case study, Fields in Cloud-Native Storage: the depth under the vessel
-- 273277840 read from the bathymetry stored as RaQuet tiles (table
-- BathymetryRaquet, converted by raquet-io and loaded by load_raquet.py), and a
-- collection of tiles that changes over time read by joining the tiles on the
-- cells of the trip and on their validity period. Each listing of the chapter is
-- preceded by its printed answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == tiles of the RaQuet file (3526)
SELECT COUNT(*) AS Tiles FROM BathymetryRaquet;

\echo == Query: when did the vessel sail over water less than 20 m deep, according to the RaQuet tiles
-- 60 | 00:11:04.256184 | 10
WITH Tiles AS (
  SELECT s.MMSI, array_agg(r.Tile) AS Tiles
  FROM Ships s, BathymetryRaquet r
  WHERE s.MMSI = 273277840 AND
    quadbin(r.Tile) IN (SELECT unnest(getValues(tquadbin(s.TripLonLat, 11))))
  GROUP BY s.MMSI ),
DepthRaquet AS (
  SELECT array_length(t.Tiles, 1) AS NumTiles,
    rasterTileValue(s.TripLonLat, t.Tiles) AS Depth
  FROM Ships s JOIN Tiles t USING (MMSI) )
SELECT NumTiles, duration(whenTrue(Depth #< 20)) AS Under20,
  numSpans(whenTrue(Depth #< 20)) AS Periods
FROM DepthRaquet;

-- The bathymetry has a single state, so the collection of tiles below gives its
-- tiles the two halves of the trip as their periods: the reading over the tiles
-- of each period merges into the reading of the whole trip.
\echo == a collection of tiles that changes over time
DROP TABLE IF EXISTS BathymetrySeries;
CREATE TABLE BathymetrySeries(Quadbin quadbin, Period tstzspan, Tile raquet);
INSERT INTO BathymetrySeries
SELECT quadbin(Tile), span(t.T1, t.T2, true, false), Tile
FROM BathymetryRaquet,
  (SELECT startTimestamp(Trip) AS T1,
     startTimestamp(Trip) + (duration(Trip) / 2) AS T2
   FROM Ships WHERE MMSI = 273277840) t;
INSERT INTO BathymetrySeries
SELECT quadbin(Tile), span(t.T2, t.T3, true, true), Tile
FROM BathymetryRaquet,
  (SELECT startTimestamp(Trip) + (duration(Trip) / 2) AS T2,
     endTimestamp(Trip) AS T3
   FROM Ships WHERE MMSI = 273277840) t;

\echo == Listing: the tiles joined on the cells of the trip and on their period (10 | 00:11:04.256184)
SELECT numSpans(whenTrue(Depth #< 20)) AS Periods,
  duration(whenTrue(Depth #< 20)) AS Under20
FROM (
  SELECT mergeAgg(rasterTileValue(atTime(s.TripLonLat, q.Period), q.Tile)
      ORDER BY q.Period) AS Depth
  FROM Ships s, BathymetrySeries q, unnest(tquadbin(s.TripLonLat, 11)) c
  WHERE s.MMSI = 273277840 AND q.Quadbin = c.value AND q.Period && c.time
  GROUP BY s.MMSI ) x;
