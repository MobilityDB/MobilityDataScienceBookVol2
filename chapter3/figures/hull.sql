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

-- Fig. ais_hull_turn: the hull of the ro-ro vessel FICARIA SEAWAYS (MMSI 220464000) turning in the
-- harbour of Goeteborg on January 20, 2026, between 18:39 and 18:45, six placements 72 s apart,
-- and the trajectory of its GPS antenna. Reads the table ShipsRigid of chapter 4 in the AIS
-- database of the book.
-- psql -d ais -v out=<dir> -f hull.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
SET TimeZone = 'UTC';
\o :out/hull.geojson
WITH Turn(Trip) AS (
  SELECT atTime(Trip, tstzspan '[2026-01-20 18:39:00+00, 2026-01-20 18:45:00+00]')
  FROM ShipsRigid WHERE MMSI = 220464000 ),
Layer(Name, G) AS (
  SELECT 'p' || i, valueAtTimestamp(t.Trip, timestamptz '2026-01-20 18:39:00+00' + (i * interval '72 s'))
  FROM Turn t, generate_series(0, 5) AS i
  UNION ALL
  SELECT 'antenna', trajectory(tgeompoint(Trip)) FROM Turn )
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', Name),
  'geometry', ST_AsGeoJSON(ST_Transform(G, 4326), 9)::json))) FROM Layer;
\o
WITH Turn(Trip) AS (
  SELECT atTime(Trip, tstzspan '[2026-01-20 18:39:00+00, 2026-01-20 18:45:00+00]')
  FROM ShipsRigid WHERE MMSI = 220464000 ),
G(G) AS (SELECT traversedArea(Trip) FROM Turn)
SELECT ST_AsText(ST_Transform(ST_Centroid(ST_Envelope(G)), 4326)),
  round(ST_XMax(G) - ST_XMin(G)), round(ST_YMax(G) - ST_YMin(G)), ST_SRID(G) FROM G;
