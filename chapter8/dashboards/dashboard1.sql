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

-- Dashboard 1, Noise Heatmap and Altitude of Flights Leaving Brussels: the positions below
-- 2,000 meters of the flights over Brussels while they climb. Each row gives the altitude, the
-- vertical rate and the position of one flight at the same instant T. It is the query of
-- flights/flights_dashboards.sql in MobilitySpark, as Sect. "Dashboard 1: Flights Leaving
-- Brussels" of chapter 8 explains it.

WITH Brussels(BrusselsEnv) AS (
  SELECT geographyFromHexEWKB(ST_AsHEXEWKB(ST_SetSRID(
    ST_PolygonFromEnvelope(4.25, 50.75, 4.60, 50.95), 4326))) ),
AscSpan(Span) AS (
  SELECT floatspanFromText('[1, 20]') ),
TimePeriod(Period) AS (
  SELECT tstzspanFromText('[2026-03-01 00:00:00+00, 2026-03-01 23:59:00+00)') ),
TargetFlight(ICAO24, CallSign, RestFlight, RestGeoAlt, RestVertRate) AS (
  SELECT ICAO24, CallSign, atGeometry(atTime(Flight, Period), BrusselsEnv),
    atTime(GeoAltitude, Period), atTime(VertRate, Period)
  FROM Flights, TimePeriod, Brussels
  WHERE atGeometry(atTime(Flight, Period), BrusselsEnv) IS NOT NULL ),
FlightAscent(ICAO24, CallSign, RestGeoAlt, AscTrip, RestVertRate) AS (
  SELECT ICAO24, CallSign,
    atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))),
    atTime(RestFlight, getTime(atSpan(RestVertRate, Span))),
    atSpan(RestVertRate, Span)
  FROM TargetFlight, AscSpan
  WHERE atSpan(RestVertRate, Span) IS NOT NULL AND
    atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))) IS NOT NULL AND
    atTime(RestFlight, getTime(atSpan(RestVertRate, Span))) IS NOT NULL ),
Instants(ICAO24, CallSign, T) AS (
  SELECT ICAO24, CallSign, T
  FROM FlightAscent
  LATERAL VIEW explode(setUnnest(setUnion(setUnion(setMake(timestamps(RestGeoAlt)),
    setMake(timestamps(AscTrip))), setMake(timestamps(RestVertRate))))) e AS T )
SELECT f.ICAO24, f.CallSign, valueAtTimestamp(RestGeoAlt, T) AS GeoAltitude,
  valueAtTimestamp(RestVertRate, T) AS VertRate,
  startValue(getX(atTime(AscTrip, T))) AS Lon,
  startValue(getY(atTime(AscTrip, T))) AS Lat, T
FROM FlightAscent f, Instants i
WHERE f.ICAO24 = i.ICAO24 AND f.CallSign = i.CallSign AND
  valueAtTimestamp(AscTrip, T) IS NOT NULL AND
  valueAtTimestamp(RestGeoAlt, T) IS NOT NULL AND
  valueAtTimestamp(RestVertRate, T) IS NOT NULL AND
  valueAtTimestamp(RestGeoAlt, T) < 2000
ORDER BY f.ICAO24, f.CallSign, T
