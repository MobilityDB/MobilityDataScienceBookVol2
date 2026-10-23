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

-- Data of the four maps of the DuckDB section (Figs. duckdbcentroid, ships1000m, countships1000m,
-- k-5-NN), from the queries printed in the chapter, written as CSV for fig_duck.py.
SET TimeZone = 'UTC';
SET geometry_always_xy = true;
COPY (
SELECT MMSI, DATE_TRUNC('hour', t) AS ReportHour,
  ST_AsText(ST_Centroid(ST_Collect(ARRAY_AGG(geom)))) AS centroid_wkt
FROM AISInput
GROUP BY MMSI, ReportHour
ORDER BY MMSI, ReportHour
) TO 'data/ais/centroids.csv' (HEADER);
COPY (
WITH Target AS (
  SELECT Geom, t
  FROM AISInput
  WHERE MMSI = 219015442
  ORDER BY t DESC
  LIMIT 1 )
SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom
FROM AISInput other, Target t
WHERE other.MMSI <> 219015442 AND
  ST_Distance_Sphere(other.Geom, t.Geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60
) TO 'data/ais/ships1000m.csv' (HEADER);
COPY (
SELECT ST_AsText(Geom) AS Geom, t FROM AISInput WHERE MMSI = 219015442 ORDER BY t DESC LIMIT 1
) TO 'data/ais/target.csv' (HEADER);
COPY (
WITH Latest AS (
  SELECT MMSI, geom, t
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI
      ORDER BY t DESC) AS RowNo
    FROM AISInput )
  WHERE RowNo = 1 ),
Neighbors AS (
  SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2
  FROM Latest l1, Latest l2
  WHERE l1.MMSI <> l2.MMSI AND
    ST_Distance_Sphere(l1.Geom, l2.Geom) <= 1000 AND
    ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60 )
SELECT l.MMSI, ST_AsText(l.Geom) AS Geom, COUNT(n.MMSI2) AS NeighborCount
FROM Latest l LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1
GROUP BY l.MMSI, l.Geom
ORDER BY NeighborCount DESC
) TO 'data/ais/countships1000m.csv' (HEADER);
COPY (
WITH Latest AS (
  SELECT MMSI, geom, t
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI
      ORDER BY t DESC) AS RowNo
    FROM AISInput )
  WHERE RowNo = 1 ),
Target AS (
  SELECT MMSI, geom, t
  FROM Latest
  WHERE MMSI = 219015442 )
SELECT o.MMSI, ST_AsText(o.geom) AS geom,
  ST_Distance_Sphere(o.geom, t.geom) AS Distance,
  ABS(EXTRACT(EPOCH FROM (o.t - t.t))) AS TimeDiff
FROM Latest o JOIN Target t ON o.MMSI <> t.MMSI
WHERE ST_Distance_Sphere(o.geom, t.geom) <= 1000 AND
  ABS(EXTRACT(EPOCH FROM (o.t - t.t))) <= 60
ORDER BY Distance
LIMIT 5
) TO 'data/ais/k5nn.csv' (HEADER);
