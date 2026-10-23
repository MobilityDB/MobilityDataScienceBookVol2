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

-- The flights tables of the book in MobilityDB: FlightsInput, FlightsDay and Flights, built from
-- the state vectors that build.sh copies into FlightsInputRaw. The statements follow the script
-- opensky_input.sql of chapter 5 of the first volume one for one, and the notebook
-- chapter8/8.3 Create tables from scratch-flights-MobilitySpark.ipynb builds the same tables in
-- Spark: the columns have the types of that notebook, and the call sign is trimmed as there, so
-- that the two engines read the same values. The timestamps are read in UTC.
--
--   psql -d flights -f flights_build.sql

\set ON_ERROR_STOP on
SET timezone = 'UTC';

-- The state vectors that have a squawk, of the aircraft that report a position at least once,
-- with their timestamps and their point
DROP TABLE IF EXISTS FlightsInput CASCADE;
CREATE TABLE FlightsInput AS
WITH ICAO24_WithNullLon AS (
  SELECT ICAO24
  FROM FlightsInputRaw
  GROUP BY ICAO24
  HAVING COUNT(Lon) = 0 )
SELECT Et, ICAO24, Lat, Lon, Velocity, Heading, VertRate, CallSign, OnGround, Alert, SPI,
  Squawk, BaroAltitude, GeoAltitude, LastPosUpdate, LastContact,
  to_timestamp(Et) AS EtTs,
  to_timestamp(LastPosUpdate) AS LastPosUpdateTs,
  to_timestamp(LastContact) AS LastContactTs,
  ST_Point(Lon, Lat, 4326) AS Geo
FROM FlightsInputRaw
WHERE Squawk IS NOT NULL AND
  ICAO24 NOT IN (SELECT ICAO24 FROM ICAO24_WithNullLon);
DROP TABLE FlightsInputRaw;

CREATE INDEX FlightsInput_ICAO24_EtTs_idx ON FlightsInput (ICAO24, EtTs);

SELECT COUNT(*) AS States, COUNT(DISTINCT ICAO24) AS Aircraft FROM FlightsInput;

-- The position reports. A state vector repeats the last position of its aircraft until a new
-- position report arrives, and LastPosUpdate is the time of that report, so a report is taken
-- once, at its time, from the first state vector that carries it. The reports then follow the
-- walk of ais/ais_clean.sql, with the speed of an aircraft for that of a vessel: a report is kept
-- when the last kept one could reach it at 400 m/s along the great circle; the seed is the
-- earliest of the first eleven reports a majority of them can reach, the reports before it are
-- walked backwards from it, and an aircraft whose share of reports unreachable from the report
-- before exceeds one half is dropped whole.
CREATE OR REPLACE FUNCTION pg_temp.reach(d float8, dt float8) RETURNS bool
  LANGUAGE sql IMMUTABLE AS $$ SELECT d <= 400 * dt $$;

CREATE TEMP TABLE Reports AS
SELECT ICAO24, row_number() OVER (PARTITION BY ICAO24 ORDER BY LastPosUpdate) AS Rn,
  LastPosUpdate AS Ts, LastPosUpdateTs, Lon, Lat, GeoAltitude, Geo, Geo::geography AS Geog
FROM (
  SELECT ICAO24, LastPosUpdate, LastPosUpdateTs, Lon, Lat, GeoAltitude, Geo,
    row_number() OVER (PARTITION BY ICAO24, LastPosUpdate ORDER BY Et) AS RowNo
  FROM FlightsInput
  WHERE Geo IS NOT NULL AND LastPosUpdate IS NOT NULL ) P
WHERE RowNo = 1;
CREATE INDEX ON Reports (ICAO24, Rn);
ANALYZE Reports;

-- The aircraft whose share of reports unreachable from the report before is at most one half.
CREATE TEMP TABLE KeepAircraft AS
SELECT ICAO24 FROM (
  SELECT ICAO24, NOT coalesce(pg_temp.reach(ST_Distance(lag(Geog) OVER W, Geog),
                                            Ts - lag(Ts) OVER W), true) AS Unreachable
  FROM Reports WINDOW W AS (PARTITION BY ICAO24 ORDER BY Rn)) S
GROUP BY ICAO24 HAVING AVG(Unreachable::int) <= 0.5;

-- The walk trusts its first report, so the seed is corroborated: the earliest of the first eleven
-- reports of an aircraft that a majority of them can reach.
CREATE TEMP TABLE Head AS
SELECT R.ICAO24, R.Rn, R.Ts, R.Geog FROM Reports R JOIN KeepAircraft USING (ICAO24)
WHERE R.Rn <= 11;

CREATE TEMP TABLE Seed AS
SELECT ICAO24, coalesce(MIN(Rn) FILTER (WHERE Ok * 2 >= Others), 1) AS SeedRn
FROM (
  SELECT a.ICAO24, a.Rn,
    COUNT(*) FILTER (WHERE b.Rn <> a.Rn AND b.Ts <> a.Ts
      AND pg_temp.reach(ST_Distance(a.Geog, b.Geog), abs(b.Ts - a.Ts))) AS Ok,
    COUNT(*) - 1 AS Others
  FROM Head a JOIN Head b USING (ICAO24)
  GROUP BY a.ICAO24, a.Rn) A
GROUP BY ICAO24;

-- The track from the seed on, cut into runs at each report unreachable from the report before
-- it. Inside a run every step is reachable, so the walk decides only, per run, the first report
-- where the track is rejoined.
CREATE TEMP TABLE Fwd AS
SELECT ICAO24, Rn, Ts, Geog,
  SUM(CASE WHEN NOT coalesce(pg_temp.reach(DPrev, DtPrev), true) THEN 1 ELSE 0 END)
    OVER (PARTITION BY ICAO24 ORDER BY Rn) AS RunId
FROM (
  SELECT R.ICAO24, R.Rn, R.Ts, R.Geog,
    R.Ts - lag(R.Ts) OVER W AS DtPrev, ST_Distance(lag(R.Geog) OVER W, R.Geog) AS DPrev
  FROM Reports R JOIN Seed S USING (ICAO24)
  WHERE R.Rn >= S.SeedRn
  WINDOW W AS (PARTITION BY R.ICAO24 ORDER BY R.Rn)) F;
CREATE INDEX ON Fwd (ICAO24, RunId, Rn);

-- The last report of each run, the anchor it hands on.
CREATE TEMP TABLE Runs AS
SELECT DISTINCT ON (ICAO24, RunId) ICAO24, RunId, Rn AS LastRn, Ts AS LastTs, Geog AS LastGeog
FROM Fwd ORDER BY ICAO24, RunId, Rn DESC;
CREATE INDEX ON Runs (ICAO24, RunId);
ANALYZE Fwd;
ANALYZE Runs;

-- One step per run, carrying the anchor, the last kept report. Cut is the first report of the
-- run reachable from the anchor; the reports before it are dropped. A run with no reachable
-- report is dropped whole and leaves the anchor in place.
CREATE TEMP TABLE Walk AS
WITH RECURSIVE W AS (
  SELECT ICAO24, RunId, 0::bigint AS Cut, LastTs AS ATs, LastGeog AS AGeog
  FROM Runs WHERE RunId = 0
  UNION ALL
  SELECT r.ICAO24, r.RunId,
    coalesce(x.K, r.LastRn + 1),
    CASE WHEN x.K IS NULL THEN w.ATs ELSE r.LastTs END,
    CASE WHEN x.K IS NULL THEN w.AGeog ELSE r.LastGeog END
  FROM W w
  JOIN Runs r ON r.ICAO24 = w.ICAO24 AND r.RunId = w.RunId + 1
  CROSS JOIN LATERAL (SELECT (
    SELECT f.Rn FROM Fwd f
    WHERE f.ICAO24 = r.ICAO24 AND f.RunId = r.RunId AND f.Ts > w.ATs
      AND pg_temp.reach(ST_Distance(w.AGeog, f.Geog), f.Ts - w.ATs)
    ORDER BY f.Rn LIMIT 1) AS K) x)
SELECT ICAO24, RunId, Cut FROM W;

-- The reports before the seed, walked backwards from it by the same rule.
CREATE TEMP TABLE PreKeep AS
WITH RECURSIVE B AS (
  SELECT H.ICAO24, H.Rn, H.Ts AS ATs, H.Geog AS AGeog, false AS Kept
  FROM Head H JOIN Seed S ON S.ICAO24 = H.ICAO24 AND H.Rn = S.SeedRn
  WHERE S.SeedRn > 1
  UNION ALL
  SELECT b.ICAO24, h.Rn,
    CASE WHEN r.Ok THEN h.Ts ELSE b.ATs END,
    CASE WHEN r.Ok THEN h.Geog ELSE b.AGeog END,
    r.Ok
  FROM B b
  JOIN Head h ON h.ICAO24 = b.ICAO24 AND h.Rn = b.Rn - 1
  CROSS JOIN LATERAL (SELECT pg_temp.reach(ST_Distance(b.AGeog, h.Geog), b.ATs - h.Ts) AS Ok) r)
SELECT ICAO24, Rn FROM B WHERE Kept;

-- The position reports the walk keeps
DROP TABLE IF EXISTS FlightsPositions CASCADE;
CREATE TABLE FlightsPositions AS
SELECT R.ICAO24, R.LastPosUpdateTs AS PosTs, R.Lon, R.Lat, R.GeoAltitude, R.Geo
FROM Reports R
JOIN (
  SELECT F.ICAO24, F.Rn FROM Fwd F JOIN Walk W USING (ICAO24, RunId) WHERE F.Rn >= W.Cut
  UNION ALL
  SELECT ICAO24, Rn FROM PreKeep) C USING (ICAO24, Rn);
CREATE INDEX ON FlightsPositions (ICAO24, PosTs);
ANALYZE FlightsPositions;

SELECT (SELECT COUNT(*) FROM Reports) AS Reports, COUNT(*) AS KeptReports,
  COUNT(DISTINCT ICAO24) AS Aircraft
FROM FlightsPositions;

-- The day of each aircraft, its trajectory and its attributes as temporal values
DROP TABLE IF EXISTS FlightsDay CASCADE;
CREATE TABLE FlightsDay(ICAO24, Flight, Velocity, Heading, VertRate, CallSign, Alert,
  GeoAltitude) AS
WITH Trajectories AS (
  SELECT ICAO24, tgeogpointSeq(array_agg(tgeogpoint(Geo, PosTs) ORDER BY PosTs)) AS Flight
  FROM FlightsPositions
  GROUP BY ICAO24 ),
Attributes AS (
  SELECT ICAO24,
    tfloatSeq(array_agg(tfloat(Velocity, EtTs) ORDER BY EtTs)
      FILTER (WHERE Velocity IS NOT NULL)) AS Velocity,
    tfloatSeq(array_agg(tfloat(Heading, EtTs) ORDER BY EtTs)
      FILTER (WHERE Heading IS NOT NULL)) AS Heading,
    tfloatSeq(array_agg(tfloat(VertRate, EtTs) ORDER BY EtTs)
      FILTER (WHERE VertRate IS NOT NULL)) AS VertRate,
    ttextSeq(array_agg(ttext(trim(CallSign), EtTs) ORDER BY EtTs)
      FILTER (WHERE CallSign IS NOT NULL)) AS CallSign,
    tboolSeq(array_agg(tbool(Alert, EtTs) ORDER BY EtTs)
      FILTER (WHERE Alert IS NOT NULL)) AS Alert,
    tfloatSeq(array_agg(tfloat(GeoAltitude, EtTs) ORDER BY EtTs)
      FILTER (WHERE GeoAltitude IS NOT NULL)) AS GeoAltitude
  FROM FlightsInput
  GROUP BY ICAO24 )
SELECT a.ICAO24, t.Flight, a.Velocity, a.Heading, a.VertRate, a.CallSign, a.Alert,
  a.GeoAltitude
FROM Attributes a LEFT JOIN Trajectories t ON t.ICAO24 = a.ICAO24;

-- The flights, one per aircraft and call sign, with the attributes of the aircraft restricted
-- to the periods of the call sign
DROP TABLE IF EXISTS Flights CASCADE;
CREATE TABLE Flights(ICAO24, CallSign, FlightPeriod, Flight, Velocity, Heading, VertRate, Alert,
  GeoAltitude) AS
SELECT ICAO24, (Rec).Value, (Rec).Time,
  atTime(Flight, (Rec).Time), atTime(Velocity, (Rec).Time),
  atTime(Heading, (Rec).Time), atTime(VertRate, (Rec).Time),
  atTime(Alert, (Rec).Time), atTime(GeoAltitude, (Rec).Time)
FROM FlightsDay f, unnest(f.CallSign) AS Rec;

-- The summary that the notebook prints
SELECT COUNT(*) AS Aircraft, COUNT(Flight) AS WithFlight, SUM(numInstants(Flight)) AS Instants
FROM FlightsDay;
SELECT COUNT(*) AS Flights, COUNT(DISTINCT ICAO24) AS Aircraft,
  COUNT(DISTINCT CallSign) AS CallSigns,
  COUNT(*) FILTER (WHERE CallSign = '') AS WithoutCallSign
FROM Flights;
