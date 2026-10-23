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

-- Raster Data in PostGIS: the loaded bathymetry and the basic queries of the
-- tutorial. Every table is in EPSG:25832, so no query transforms a geometry.
-- Each listing of the chapter is preceded by its printed answer.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == tiles of the bathymetry and size of the table (886 tiles, 173 MB)
SELECT COUNT(*) AS Tiles,
  pg_size_pretty(pg_total_relation_size('bathymetry')) AS Size
FROM Bathymetry;

\echo == Listing: metadata of a tile
/* upperleftx | upperlefty | width | height | scalex | scaley | skewx | skewy |
   550300     | 6466200    | 256   | 256    | 50     | -50    | 0     | 0     |
   srid  | numbands
   25832 | 1 */
SELECT (ST_MetaData(Rast)).* FROM Bathymetry ORDER BY rid LIMIT 1;

\echo == Query: depth at a position in the roads of Frederikshavn (8.88)
SELECT ST_Value(Rast, geometry 'SRID=25832;Point(596041 6367497)') AS Depth
FROM Bathymetry
WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)');

\echo == Query: resample the tile under the roads of Frederikshavn to pixels of 500 m (26 | 500)
SELECT ST_Width(r) AS Width, ST_ScaleX(r) AS ScaleX
FROM (
  SELECT ST_Rescale(Rast, 500) AS r
  FROM Bathymetry
  WHERE ST_Intersects(Rast, geometry 'SRID=25832;Point(596041 6367497)') ) t;
