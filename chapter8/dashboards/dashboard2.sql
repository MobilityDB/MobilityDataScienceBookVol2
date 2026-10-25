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
-- the table ClosePair of dashboards_tables.sql holds. Its four panels are the queries of
-- flights/flights_dashboards.sql in MobilitySpark, as Sect. "Dashboard 2: Close Flights" of
-- chapter 8 explains them.

-- Distance Between Two Planes: the distance in kilometers between the two flights over time, in
-- three dimensions. Spark joins the tables of a FROM clause in their order, taking a condition
-- on the first two as their join condition: ClosePair comes first, so that each flight is
-- joined with it, where FlightsEU3D s1, FlightsEU3D s2 first would pair every two flights.
WITH MinDist AS (
  SELECT tDistance(s1.Trip, s2.Trip) AS Distance
  FROM ClosePair p, FlightsEU3D s1, FlightsEU3D s2
  WHERE s1.ICAO24 = p.ICAO24_1 AND s1.CallSign = p.CallSign_1 AND
    s2.ICAO24 = p.ICAO24_2 AND s2.CallSign = p.CallSign_2 AND
    atMin(tDistance(s1.Trip, s2.Trip)) IS NOT NULL )
SELECT startTimestamp(i) AS Time, startValue(i) / 1000 AS Distance
FROM MinDist
LATERAL VIEW explode(instants(Distance)) e AS i
ORDER BY Time;

-- Position of Close Flights: the position reports of the two flights that FlightsPositions
-- keeps, each at the time of the report
SELECT p.PosTs, CASE WHEN p.ICAO24 = c.ICAO24_1 THEN 1 ELSE 2 END AS Aircraft,
  p.Lat, p.Lon
FROM FlightsPositions p, Flights f, ClosePair c
WHERE p.ICAO24 = f.ICAO24 AND spansetContains(f.FlightPeriod, p.PosTs) AND
  ((f.ICAO24 = c.ICAO24_1 AND f.CallSign = c.CallSign_1) OR
   (f.ICAO24 = c.ICAO24_2 AND f.CallSign = c.CallSign_2))
ORDER BY Aircraft, p.PosTs;

-- Geoaltitude vs Time, for each of the two flights: the state vectors of the flight, each at
-- the time etts of its state vector
SELECT i.EtTs, i.GeoAltitude
FROM FlightsInput i, Flights f, ClosePair p
WHERE i.ICAO24 = f.ICAO24 AND spansetContains(f.FlightPeriod, i.EtTs) AND
  f.ICAO24 = p.ICAO24_1 AND f.CallSign = p.CallSign_1
ORDER BY i.EtTs;

SELECT i.EtTs, i.GeoAltitude
FROM FlightsInput i, Flights f, ClosePair p
WHERE i.ICAO24 = f.ICAO24 AND spansetContains(f.FlightPeriod, i.EtTs) AND
  f.ICAO24 = p.ICAO24_2 AND f.CallSign = p.CallSign_2
ORDER BY i.EtTs
