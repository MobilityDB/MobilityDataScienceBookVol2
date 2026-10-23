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

-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 4: Temporal Poses and Temporal Rigid Geometries
--
-- The 111 turbines of the Anholt offshore wind farm
--
-- Reads data/anholt_turbines.csv, the positions of the turbines as mapped in
-- OpenStreetMap (nodes tagged generator:source=wind in the farm), (c)
-- OpenStreetMap contributors, available under the Open Database License,
-- https://www.openstreetmap.org/copyright. Run from this directory:
--   psql -d ais -f load_turbines.sql
--
-- Last run against PostgreSQL 18.6, PostGIS 3.6.4, MobilityDB 1.4.
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS Turbines;
CREATE TABLE Turbines(OsmId bigint PRIMARY KEY, Lon float, Lat float);
\copy Turbines FROM 'data/anholt_turbines.csv' CSV HEADER
ALTER TABLE Turbines ADD COLUMN Geom geometry(Point, 25832);
UPDATE Turbines SET Geom = ST_Transform(ST_Point(Lon, Lat, 4326), 25832);

-- The location of the farm and its extent, as the figure of the chapter draws
-- them: the centroid of the turbines, and their convex and concave hulls
SELECT COUNT(*) AS Turbines,
  round(ST_Area(ST_ConvexHull(ST_Collect(Geom))) / 1e6, 1) AS ConvexKm2,
  round(ST_Area(ST_ConcaveHull(ST_Collect(Geom), 0.3)) / 1e6, 1) AS ConcaveKm2
FROM Turbines;
-- 111 | 119 | 92.1
