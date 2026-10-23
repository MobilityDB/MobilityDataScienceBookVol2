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

-- Dashboard 3, Flights in the Morning: the flights between 8 and 9 o'clock UTC, and those of them
-- that cruise between 3,000 and 8,000 meters. Its two panels are the queries of
-- flights/flights_dashboards.sql in MobilitySpark, as Sect. "Dashboard 3: Flights in the Morning"
-- of chapter 8 explains them. Each panel returns the positions that the map of the dashboard
-- draws; the dashboard states their number, their aircraft and their average altitude, the
-- summary that flights_dashboards.sql returns.

-- GPS Location Over Time: the positions and altitudes of the flights between 8 and 9 o'clock.
-- The n-th instant of the trajectory and the n-th instant of the altitude of a flight form one
-- row, a value with fewer instants giving NULL for the remaining ones, as the set-returning
-- functions of one select list do in PostgreSQL.
WITH Period(P) AS (
  SELECT tstzspanFromText('[2026-03-01 08:00:00+00, 2026-03-01 09:00:00+00)') ),
FlightTimeSlice(ICAO24, CallSign, TripTimeSlice, GeoAltitude) AS (
  SELECT icao24, callsign, atTime(flight, P), atTime(geoaltitude, P)
  FROM flights, Period
  WHERE atTime(flight, P) IS NOT NULL ),
Positions(ICAO24, CallSign, N, Pos) AS (
  SELECT ICAO24, CallSign, N, Pos
  FROM FlightTimeSlice
  LATERAL VIEW posexplode(instants(TripTimeSlice)) e AS N, Pos ),
Altitudes(ICAO24, CallSign, N, Alt) AS (
  SELECT ICAO24, CallSign, N, Alt
  FROM FlightTimeSlice
  LATERAL VIEW posexplode(instants(GeoAltitude)) e AS N, Alt ),
FinalOutput AS (
  SELECT coalesce(p.ICAO24, a.ICAO24) AS ICAO24, startValue(a.Alt) AS Altitude,
    startValue(getX(p.Pos)) AS Lon, startValue(getY(p.Pos)) AS Lat
  FROM Positions p FULL JOIN Altitudes a ON p.ICAO24 = a.ICAO24 AND
    p.CallSign = a.CallSign AND p.N = a.N )
SELECT ICAO24, Altitude, Lon, Lat
FROM FinalOutput;

-- Cruising Flights: the positions of the flights between 8 and 9 o'clock while they fly
-- between 3,000 and 8,000 meters. Each row reads the altitude and the position of a flight at
-- the same instant, an instant of its cruising trajectory or of its cruising altitude.
WITH TimeAltitude(Period, AltSpan) AS (
  SELECT tstzspanFromText('[2026-03-01 08:00:00+00, 2026-03-01 09:00:00+00)'),
    floatspanFromText('[3000, 8000)') ),
FlightTimeSlice(ICAO24, CallSign, TripTimeSlice, AltTimeSlice) AS (
  SELECT icao24, callsign, atTime(flight, Period), atTime(geoaltitude, Period)
  FROM flights, TimeAltitude
  WHERE atTime(flight, Period) IS NOT NULL ),
FlightTimeSliceCruising(ICAO24, CallSign, CruisingTrip, CruisingAltitude) AS (
  SELECT ICAO24, CallSign,
    atTime(TripTimeSlice, getTime(atSpan(AltTimeSlice, AltSpan))),
    atSpan(AltTimeSlice, AltSpan)
  FROM FlightTimeSlice, TimeAltitude
  WHERE atSpan(AltTimeSlice, AltSpan) IS NOT NULL AND
    atTime(TripTimeSlice, getTime(atSpan(AltTimeSlice, AltSpan))) IS NOT NULL ),
Instants(ICAO24, CallSign, T) AS (
  SELECT ICAO24, CallSign, T
  FROM FlightTimeSliceCruising
  LATERAL VIEW explode(setUnnest(setUnion(setMake(timestamps(CruisingTrip)),
    setMake(timestamps(CruisingAltitude))))) e AS T )
SELECT f.ICAO24, valueAtTimestamp(CruisingAltitude, T) AS Altitude,
  startValue(getX(atTime(CruisingTrip, T))) AS Lon,
  startValue(getY(atTime(CruisingTrip, T))) AS Lat, T
FROM FlightTimeSliceCruising f, Instants i
WHERE f.ICAO24 = i.ICAO24 AND f.CallSign = i.CallSign AND
  valueAtTimestamp(CruisingAltitude, T) IS NOT NULL AND
  valueAtTimestamp(CruisingTrip, T) IS NOT NULL
