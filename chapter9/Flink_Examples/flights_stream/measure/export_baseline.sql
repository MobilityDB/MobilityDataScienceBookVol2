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

-- The answers of MobilityDB that compare.py compares with the topics of the air traffic stream,
-- from the tables that flights/flights_build.sql and flights/flights_dashboards.sql build:
-- positions.csv, the aircraft and the time in milliseconds since 1970 of each position report
-- of FlightsPositions, without header, and d1.csv, the rows of the query of dashboard 1 of
-- flights_dashboards.sql, with header. Both are written into the working directory.
--
--   mkdir -p baseline && cd baseline && psql -d flights -f <this directory>/export_baseline.sql

\set ON_ERROR_STOP on
SET timezone = 'UTC';
\copy (SELECT ICAO24, (extract(epoch from PosTs)*1000)::bigint FROM FlightsPositions) TO 'positions.csv' CSV
\copy (WITH Brussels(BrusselsEnv) AS ( SELECT ST_MakeEnvelope(4.25, 50.75, 4.60, 50.95, 4326)::geography ), AscSpan(Span) AS ( SELECT floatspan '[1,20]' ), TimePeriod(Period) AS ( SELECT tstzspan '[2026-03-01 00:00:00, 2026-03-01 23:59:00)' ), TargetFlight(ICAO24, CallSign, RestFlight, RestGeoAlt, RestVertRate) AS ( SELECT ICAO24, CallSign, atGeometry(atTime(Flight, Period), BrusselsEnv), atTime(GeoAltitude, Period), atTime(VertRate, Period) FROM Flights, TimePeriod, Brussels WHERE atGeometry(atTime(Flight, Period), BrusselsEnv) IS NOT NULL ), FlightAscent(ICAO24, CallSign, RestGeoAlt, AscTrip, RestVertRate) AS ( SELECT ICAO24, CallSign, atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))), atTime(RestFlight, getTime(atSpan(RestVertRate, Span))), atSpan(RestVertRate, Span) FROM TargetFlight, AscSpan WHERE atSpan(RestVertRate, Span) IS NOT NULL AND atTime(RestGeoAlt, getTime(atSpan(RestVertRate, Span))) IS NOT NULL AND atTime(RestFlight, getTime(atSpan(RestVertRate, Span))) IS NOT NULL ), Instants(ICAO24, CallSign, T) AS ( SELECT ICAO24, CallSign, unnest(set(timestamps(RestGeoAlt)) + set(timestamps(AscTrip)) + set(timestamps(RestVertRate))) FROM FlightAscent ) SELECT f.ICAO24, f.CallSign, getValue(atTime(RestGeoAlt, T)) AS GeoAltitude, getValue(atTime(RestVertRate, T)) AS VertRate, ST_X(getValue(atTime(AscTrip, T))::geometry) AS Lon, ST_Y(getValue(atTime(AscTrip, T))::geometry) AS Lat, T FROM FlightAscent f, Instants i WHERE f.ICAO24 = i.ICAO24 AND f.CallSign = i.CallSign AND getValue(atTime(AscTrip, T)) IS NOT NULL AND getValue(atTime(RestGeoAlt, T)) IS NOT NULL AND getValue(atTime(RestVertRate, T)) IS NOT NULL AND getValue(atTime(RestGeoAlt, T)) < 2000 ORDER BY f.ICAO24, f.CallSign, T) TO 'd1.csv' CSV HEADER
