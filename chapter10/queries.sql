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
-- Chapter 10: Mobility Data Pipelines
--
-- The queries of Sect. "Querying the Lakehouse", as printed in the chapter, with the
-- subquery PortB and the candidate pairs Cand written out where the chapter elides them.
-- Each statement is preceded by the region it is evaluated on and, for the two pairwise
-- queries, the value of :gate, as benchmark/planar/70_queries.py of MobilityLakehouse sets
-- them. bind.py replaces the parameters by the values of a window and prefixes the view
-- trips over a layout; run_duckdb.sh then runs the result, as the README says.
-------------------------------------------------------------------------------

-- @region ports
-- Query 1: How many vessels called at both the Rodby and the Puttgarden ferry ports during
-- the window?
WITH PortA AS (
  SELECT DISTINCT MMSI FROM trips
  -- MBB filter: pruned with the statistics of files and row groups
  WHERE trip_xmin <= :axmax AND trip_xmax >= :axmin AND
    trip_ymin <= :aymax AND trip_ymax >= :aymin AND
    trip_tmin <= :t1 AND trip_tmax >= :t0 AND dt BETWEEN :d0 AND :d1 AND
  -- Refinement: exact predicate on the remaining trajectories
    atStbox(tgeompointFromEWKB(trip), stbox(
      'SRID=25832;STBOX XT(((:axmin,:aymin),(:axmax,:aymax)),[:t0,:t1])'))
      IS NOT NULL ),
PortB AS (
  SELECT DISTINCT MMSI FROM trips
  WHERE trip_xmin <= :bxmax AND trip_xmax >= :bxmin AND
    trip_ymin <= :bymax AND trip_ymax >= :bymin AND
    trip_tmin <= :t1 AND trip_tmax >= :t0 AND dt BETWEEN :d0 AND :d1 AND
    atStbox(tgeompointFromEWKB(trip), stbox(
      'SRID=25832;STBOX XT(((:bxmin,:bymin),(:bxmax,:bymax)),[:t0,:t1])'))
      IS NOT NULL )
SELECT COUNT(*) AS NoBoth FROM PortA a JOIN PortB b USING (MMSI);

-- @region goteborg
-- Query 2: How many distinct vessels were present in the Port of Goteborg during the window?
WITH Port AS (
  SELECT ST_MakeEnvelope(:rxmin, :rymin, :rxmax, :rymax) AS Geom ),
Cand AS (
  SELECT MMSI, atTime(tgeompointFromEWKB(trip), span(:t0, :t1, true, true))
    AS Trip
  FROM trips
  WHERE trip_xmin <= :rxmax AND trip_xmax >= :rxmin AND
    trip_ymin <= :rymax AND trip_ymax >= :rymin AND
    trip_tmin <= :t1 AND trip_tmax >= :t0 AND dt BETWEEN :d0 AND :d1 )
SELECT COUNT(DISTINCT MMSI) AS NoVessels FROM Cand, Port
WHERE Trip IS NOT NULL AND eIntersects(Trip, Port.Geom);

-- @region belt
-- The trajectories restricted to the Fehmarn Belt during the window, which Queries 3 to 10 read
CREATE OR REPLACE VIEW Strait AS
SELECT MMSI, ship_type, Trip FROM (
  SELECT MMSI, ship_type, atStbox(tgeompointFromEWKB(trip), stbox(
    'SRID=25832;STBOX XT(((:rxmin,:rymin),(:rxmax,:rymax)),[:t0,:t1])')) AS Trip
  FROM trips
  WHERE dt BETWEEN :d0 AND :d1 AND
    trip_tmax >= :t0 AND trip_tmin <= :t1 AND
    trip_xmax >= :rxmin AND trip_xmin <= :rxmax AND
    trip_ymax >= :rymin AND trip_ymin <= :rymax ) AS t
WHERE Trip IS NOT NULL;

-- @region belt
-- Query 3: How many distinct vessels were present in the belt during the window?
SELECT COUNT(DISTINCT MMSI) AS NoVessels FROM Strait;

-- @region belt
-- Query 4: The total distance traveled in the belt during the window, and how many distinct
-- vessels and ship types were involved
SELECT round(SUM(length(Trip)) / 1000.0, 1) AS TotalKm,
  COUNT(DISTINCT MMSI) AS NoVessels, COUNT(DISTINCT ship_type) AS NoTypes
FROM Strait;

-- @region belt
-- Query 5: The average area of the extent of a vessel in the belt during the window
SELECT round(AVG((XMax - XMin) * (YMax - YMin) / 1e6), 2) AS AvgBoxKm2
FROM ( SELECT MMSI, MIN(ST_XMin(trajectory(Trip))) AS XMin,
    MAX(ST_XMax(trajectory(Trip))) AS XMax,
    MIN(ST_YMin(trajectory(Trip))) AS YMin,
    MAX(ST_YMax(trajectory(Trip))) AS YMax
  FROM Strait GROUP BY MMSI ) AS t;

-- @region belt
-- Query 6: The median of the maximum speed of the vessels in the belt during the window
SELECT round(median(VMax) * 1.94384, 1) AS MedianMaxKnots
FROM ( SELECT MMSI, MAX(maxValue(speed(Trip))) AS VMax
  FROM Strait GROUP BY MMSI ) AS t;

-- @region belt
-- Query 7: How many vessels had a defined position in the belt at the middle instant of the
-- window?
SELECT COUNT(DISTINCT MMSI) AS NoVessels
FROM ( SELECT MMSI, valueAtTimestamp(Trip, :tmid) AS Pos FROM Strait ) AS t
WHERE Pos IS NOT NULL;

-- @region belt
-- @gate 2000
-- Query 8: The closest approach among the pairs of vessels that came within :gate meters
WITH Ext AS (
  SELECT MMSI, Trip, startTimestamp(Trip) AS T0, endTimestamp(Trip) AS T1,
    ST_XMin(E) AS X0, ST_XMax(E) AS X1,
    ST_YMin(E) AS Y0, ST_YMax(E) AS Y1
  FROM ( SELECT MMSI, Trip, ST_Extent(trajectory(Trip)) AS E
    FROM Strait ) AS t
  WHERE E IS NOT NULL ),
Cand AS (
  SELECT a.MMSI AS MMSI1, b.MMSI AS MMSI2, a.Trip AS Trip1, b.Trip AS Trip2
  FROM Ext a JOIN Ext b ON a.MMSI < b.MMSI AND
    a.T0 <= b.T1 AND a.T1 >= b.T0 AND
    a.X0 <= b.X1 + :gate AND b.X0 <= a.X1 + :gate AND
    a.Y0 <= b.Y1 + :gate AND b.Y0 <= a.Y1 + :gate )
SELECT round(MIN(nearestApproachDistance(Trip1, Trip2))) AS MinMeters
FROM Cand;

-- @region belt
-- @gate 300
-- Query 9: How many pairs of vessels were ever within 300 meters of each other at the same
-- instant?
WITH Ext AS (
  SELECT MMSI, Trip, startTimestamp(Trip) AS T0, endTimestamp(Trip) AS T1,
    ST_XMin(E) AS X0, ST_XMax(E) AS X1,
    ST_YMin(E) AS Y0, ST_YMax(E) AS Y1
  FROM ( SELECT MMSI, Trip, ST_Extent(trajectory(Trip)) AS E
    FROM Strait ) AS t
  WHERE E IS NOT NULL ),
Cand AS (
  SELECT a.MMSI AS MMSI1, b.MMSI AS MMSI2, a.Trip AS Trip1, b.Trip AS Trip2
  FROM Ext a JOIN Ext b ON a.MMSI < b.MMSI AND
    a.T0 <= b.T1 AND a.T1 >= b.T0 AND
    a.X0 <= b.X1 + :gate AND b.X0 <= a.X1 + :gate AND
    a.Y0 <= b.Y1 + :gate AND b.Y0 <= a.Y1 + :gate )
SELECT COUNT(DISTINCT (MMSI1, MMSI2)) AS NoPairs FROM Cand
WHERE eDwithin(Trip1, Trip2, 300);

-- @region belt
-- Query 10: How many vessels were in the belt at the same time, at most, during the window?
SELECT maxValue(tCount(Trip)) AS PeakVessels
FROM ( SELECT MMSI, mergeAgg(Trip) AS Trip FROM Strait GROUP BY MMSI ) AS t;
