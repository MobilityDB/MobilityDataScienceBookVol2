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

-- The answers of dashboard 2 of the air traffic use case of the chapter Large-Scale Mobility
-- Databases that the figures of the dashboard draw, in MobilityDB, on the tables that
-- flights/flights_build.sql and flights/flights_dashboards.sql build for March 1, 2026.
--
--   mkdir -p out && psql -d flights -f flights_dashboard2.sql
--
-- The first query prints the pieces of the closest pair of ClosePair in their tile, with their
-- nearest approach, its instant, the points of the shortest line between the two pieces in WGS84
-- (p1 and p2), their altitudes and the length of the line in three dimensions; the second the
-- periods of the two whole flights and their nearest approach. The three \copy commands write
-- the rows of the figures into out/ of the working directory: d2_distance.csv (the distance in
-- kilometers between the two flights at each instant of their temporal distance),
-- d2_positions.csv (the position reports of the two flights) and d2_altitude.csv (the altitude
-- of each state vector of the two flights), the aircraft numbered 1 and 2 as in ClosePair.
-- flights_dashboard2_maps.py draws them.

\set ON_ERROR_STOP on
SET timezone = 'UTC';
\pset footer on
-- the pieces of the closest pair and their nearest approach
SELECT a1.ICAO24, a1.CallSign, a2.ICAO24, a2.CallSign, a1.Tile,
  nearestApproachDistance(a1.Trip, a2.Trip) AS dist,
  nearestApproachInstant(a1.Trip, a2.Trip) AS inst,
  ST_AsText(ST_Transform(ST_StartPoint(shortestLine(a1.Trip, a2.Trip)), 4326)) AS p1,
  ST_AsText(ST_Transform(ST_EndPoint(shortestLine(a1.Trip, a2.Trip)), 4326)) AS p2,
  ST_Z(ST_StartPoint(shortestLine(a1.Trip, a2.Trip))) AS z1,
  ST_Z(ST_EndPoint(shortestLine(a1.Trip, a2.Trip))) AS z2,
  ST_3DLength(shortestLine(a1.Trip, a2.Trip)) AS len
FROM Airborne3D a1, Airborne3D a2, ClosePair c
WHERE a1.ICAO24 = c.ICAO24_1 AND a1.CallSign = c.CallSign_1 AND
  a2.ICAO24 = c.ICAO24_2 AND a2.CallSign = c.CallSign_2 AND a1.Tile = a2.Tile
ORDER BY dist LIMIT 3;
-- whole flights: the period, nearest approach over the whole flights
SELECT s1.ICAO24, s1.CallSign, s2.ICAO24, s2.CallSign, getTime(s1.Trip), getTime(s2.Trip),
  nearestApproachDistance(s1.Trip, s2.Trip), nearestApproachInstant(s1.Trip, s2.Trip),
  numInstants(s1.Trip <-> s2.Trip)
FROM FlightsEU3D s1, FlightsEU3D s2, ClosePair p
WHERE s1.ICAO24 = p.ICAO24_1 AND s1.CallSign = p.CallSign_1 AND
  s2.ICAO24 = p.ICAO24_2 AND s2.CallSign = p.CallSign_2;
\copy (WITH MinDist AS (SELECT s1.Trip <-> s2.Trip AS Distance FROM FlightsEU3D s1, FlightsEU3D s2, ClosePair p WHERE s1.ICAO24 = p.ICAO24_1 AND s1.CallSign = p.CallSign_1 AND s2.ICAO24 = p.ICAO24_2 AND s2.CallSign = p.CallSign_2 AND atMin(s1.Trip <-> s2.Trip) IS NOT NULL) SELECT startTimestamp(unnest(instants(Distance))) AS Time, getValue(unnest(instants(Distance))) / 1000 AS Distance FROM MinDist ORDER BY Time) TO 'out/d2_distance.csv' CSV HEADER
\copy (SELECT p.PosTs AS Time, CASE WHEN p.ICAO24 = c.ICAO24_1 THEN 1 ELSE 2 END AS Aircraft, p.Lat, p.Lon, p.GeoAltitude FROM FlightsPositions p, Flights f, ClosePair c WHERE p.ICAO24 = f.ICAO24 AND p.PosTs <@ f.FlightPeriod AND ((f.ICAO24 = c.ICAO24_1 AND f.CallSign = c.CallSign_1) OR (f.ICAO24 = c.ICAO24_2 AND f.CallSign = c.CallSign_2)) ORDER BY Aircraft, Time) TO 'out/d2_positions.csv' CSV HEADER
\copy (SELECT i.EtTs AS Time, CASE WHEN i.ICAO24 = p.ICAO24_1 THEN 1 ELSE 2 END AS Aircraft, i.GeoAltitude FROM FlightsInput i, Flights f, ClosePair p WHERE i.ICAO24 = f.ICAO24 AND i.EtTs <@ f.FlightPeriod AND ((f.ICAO24 = p.ICAO24_1 AND f.CallSign = p.CallSign_1) OR (f.ICAO24 = p.ICAO24_2 AND f.CallSign = p.CallSign_2)) ORDER BY Aircraft, Time) TO 'out/d2_altitude.csv' CSV HEADER
