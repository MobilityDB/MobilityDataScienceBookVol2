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

-- The day of each aircraft, its trajectory and its attributes as temporal values
DROP TABLE IF EXISTS FlightsDay CASCADE;
CREATE TABLE FlightsDay(ICAO24, Flight, Velocity, Heading, VertRate, CallSign, Alert,
  GeoAltitude) AS
SELECT ICAO24,
  tgeogpointSeq(array_agg(tgeogpoint(Geo, EtTs) ORDER BY EtTs) FILTER (WHERE Geo IS NOT NULL)),
  tfloatSeq(array_agg(tfloat(Velocity, EtTs) ORDER BY EtTs) FILTER (WHERE Velocity IS NOT NULL)),
  tfloatSeq(array_agg(tfloat(Heading, EtTs) ORDER BY EtTs) FILTER (WHERE Heading IS NOT NULL)),
  tfloatSeq(array_agg(tfloat(VertRate, EtTs) ORDER BY EtTs) FILTER (WHERE VertRate IS NOT NULL)),
  ttextSeq(array_agg(ttext(trim(CallSign), EtTs) ORDER BY EtTs)
    FILTER (WHERE CallSign IS NOT NULL)),
  tboolSeq(array_agg(tbool(Alert, EtTs) ORDER BY EtTs) FILTER (WHERE Alert IS NOT NULL)),
  tfloatSeq(array_agg(tfloat(GeoAltitude, EtTs) ORDER BY EtTs)
    FILTER (WHERE GeoAltitude IS NOT NULL))
FROM FlightsInput
GROUP BY ICAO24;

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
