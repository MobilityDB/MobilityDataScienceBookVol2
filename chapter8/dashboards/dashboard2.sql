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

-- Dashboard 2, the two flights that come the closest to each other over Europe, the pair that
-- the table closepair of dashboards_tables.sql holds. Its four panels are the queries of
-- flights/flights_dashboards.sql in MobilitySpark, as Sect. "Dashboard 2: Close Flights" of
-- chapter 8 explains them.

-- Distance Between Two Planes: the distance in kilometers between the two flights over time, in
-- three dimensions. Spark joins the tables of a FROM clause in their order, taking a condition
-- on the first two as their join condition: closepair comes first, so that each flight is
-- joined with it, where flightseu3d s1, flightseu3d s2 first would pair every two flights.
WITH MinDist AS (
  SELECT tDistance(s1.trip, s2.trip) AS distance
  FROM closepair p, flightseu3d s1, flightseu3d s2
  WHERE s1.icao24 = p.icao24_1 AND s1.callsign = p.callsign_1 AND
    s2.icao24 = p.icao24_2 AND s2.callsign = p.callsign_2 AND
    atMin(tDistance(s1.trip, s2.trip)) IS NOT NULL )
SELECT startTimestamp(i) AS time, startValue(i) / 1000 AS distance
FROM MinDist
LATERAL VIEW explode(instants(distance)) e AS i
ORDER BY time;

-- Position of Close Flights: the position reports of the two flights that flightspositions
-- keeps, each at the time of the report
SELECT p.posts, CASE WHEN p.icao24 = c.icao24_1 THEN 1 ELSE 2 END AS aircraft,
  p.lat, p.lon
FROM flightspositions p, flights f, closepair c
WHERE p.icao24 = f.icao24 AND spansetContains(f.flightperiod, p.posts) AND
  ((f.icao24 = c.icao24_1 AND f.callsign = c.callsign_1) OR
   (f.icao24 = c.icao24_2 AND f.callsign = c.callsign_2))
ORDER BY aircraft, p.posts;

-- Geoaltitude vs Time, for each of the two flights: the state vectors of the flight, each at
-- the time etts of its state vector
SELECT i.etts, i.geoaltitude
FROM flightsinput i, flights f, closepair p
WHERE i.icao24 = f.icao24 AND spansetContains(f.flightperiod, i.etts) AND
  f.icao24 = p.icao24_1 AND f.callsign = p.callsign_1
ORDER BY i.etts;

SELECT i.etts, i.geoaltitude
FROM flightsinput i, flights f, closepair p
WHERE i.icao24 = f.icao24 AND spansetContains(f.flightperiod, i.etts) AND
  f.icao24 = p.icao24_2 AND f.callsign = p.callsign_2
ORDER BY i.etts
