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

-- Noise layer of Figs. traversed_area_uwn and shortest_line_uwn: the traversed areas, as single
-- geometries, of the noise of SLESVIG (220323000, trip 1) and MARGRETE LAESOE (219000407, trip 1).
-- psql -d noise -v out=<dir> -f uwn_noise.sql
\set QUIET on
\pset tuples_only on
\pset format unaligned
\timing on
SET TimeZone = 'UTC';
CREATE TEMP TABLE Layer AS
SELECT MMSI::text AS mmsi, ST_UnaryUnion(ST_CurveToLine(traversedArea(Noise), 64)) AS G
FROM Ships WHERE MMSI IN (220323000, 219000407);
SELECT mmsi, GeometryType(G), round((ST_Area(G) / 1e6)::numeric, 2) FROM Layer;
\o :out/uwn_noise.geojson
SELECT json_build_object('type','FeatureCollection','features', json_agg(json_build_object(
  'type','Feature','properties', json_build_object('layer', 'noise', 'mmsi', mmsi),
  'geometry', ST_AsGeoJSON(ST_Transform(ST_CurveToLine(G, 64), 4326), 9)::json))) FROM Layer;
\o
SELECT mmsi, ST_XMin(G), ST_YMin(G), ST_XMax(G), ST_YMax(G) FROM Layer;
