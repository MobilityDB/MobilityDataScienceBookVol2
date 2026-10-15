-- Case study, Underwater Noise and the Depth of the Water: the noise of the
-- vessels of the day of the chapter (2026-01-20) under spherical spreading, under
-- spreading depending on the depth of the bathymetry, and under spreading
-- depending on the depth with the ambient noise raised by the wind of ERA5, and
-- the protected areas the noise reaches under the three models. It reads the
-- tables AISNoJump, Ships, Port, NaturalAreas, Bathymetry, and WindSpeed of
-- load_all.sh, and PortAreas of case_clearance.sql. The source level of a vessel
-- is computed at 63 Hz with the functions ComputeVc and ComputeSL of chapter 3
-- (chapter3/tcbuffer_load.sql), at the reports whose speed exceeds 3 knots,
-- outside the port areas. Each listing of the chapter is preceded by its printed
-- answer; the other queries give the numbers stated in the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

-- -----------------------------------------------------------------------------
-- Return the reference class speed (Vc) based on vessel macro-category and
-- cargo classification.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ComputeVc;
CREATE FUNCTION ComputeVc(
  VesselClassCode  integer,
  ShipTypeCode     integer,
  SpeedKnots       double precision, 
  LOA              double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
  CASE
    WHEN VesselClassCode = 1  THEN 10.6
    WHEN VesselClassCode = 2  THEN 6.4
    WHEN VesselClassCode = 3  THEN 3.7
    WHEN VesselClassCode = 4  THEN 9.5
    WHEN VesselClassCode = 5  THEN 11.1
    WHEN VesselClassCode = 6  THEN 8.0
    WHEN VesselClassCode = 7  THEN       
      CASE WHEN (LOA > 100) THEN 17.1 ELSE 9.7 END
    WHEN VesselClassCode = 9  THEN
      CASE
        WHEN (ShipTypeCode = 70 OR ShipTypeCode BETWEEN 75 AND 79) AND
          SpeedKnots <= 16 THEN 13.9   -- Bulker
        ELSE 18.0   -- Containership
      END
    WHEN VesselClassCode = 10 THEN 12.4
    WHEN VesselClassCode = 11 THEN 7.4
    ELSE NULL
  END;
$$;


-- -----------------------------------------------------------------------------
-- Compute the Source Level (SL) following the model of
-- MacGillivray & de Jong for vessel underwater radiated noise.
--
-- Inputs:
--   VesselClassCode   : vessel macro-category
--   f                 : frequency (Hz)
--   Vref              : vessel speed (knots)
--   Vc                : reference class speed (knots)
--   LOAref            : vessel length overall (metres)
--   InPort            : whether the vessel is located inside a port
--
-- Output:
--   SL (dB re 1 µPa @ 1 m)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ComputeSL;
CREATE FUNCTION ComputeSL(
  VesselClassCode  integer,           -- 9 = cargo, 10 = tanker, 7 = cruise
  f                real,              -- frequency (Hz)
  Vref             double precision,  -- vessel speed (knots)
  Vc               double precision,  -- class reference speed (knots)
  LOAref           double precision,  -- vessel length (metres)
  InPort           boolean            -- whether the vessel is located inside a port
)
RETURNS DOUBLE PRECISION
LANGUAGE plpgsql
AS $$
DECLARE
  -- Vessel class flags
  isRecreational boolean :=        (VesselClassCode = 1);
  isFishing boolean :=             (VesselClassCode = 2);
  isTug boolean :=                 (VesselClassCode = 3);
  isDredger boolean :=             (VesselClassCode = 4);
  isNaval boolean :=               (VesselClassCode = 5);
  isGovernmentResearch boolean :=  (VesselClassCode = 6);
  isCruise boolean :=              (VesselClassCode = 7);
  isCargo boolean :=               (VesselClassCode = 9);
  isTanker boolean :=              (VesselClassCode = 10);
  isOther boolean :=               (VesselClassCode = 11);

  -- Model parameters
  K  DOUBLE PRECISION;
  B  DOUBLE PRECISION;
  f1 DOUBLE PRECISION;
  D  DOUBLE PRECISION;

  -- Intermediate terms of the analytical formulation
  term1 DOUBLE PRECISION;
  term2 DOUBLE PRECISION;
  term3 DOUBLE PRECISION;
  term4 DOUBLE PRECISION;
  term5 DOUBLE PRECISION;
  term6 DOUBLE PRECISION;

  SL DOUBLE PRECISION;

  -- Preserve the original speed for low-speed port correction
  Speed DOUBLE PRECISION := Vref;

BEGIN
  -- Parameter K
  IF f < 100 AND (isCargo OR isTanker) THEN K := 208;
  ELSE K := 191;
  END IF;

  -- Parameter B
  IF f < 100 AND (isCargo OR isTanker) THEN B := 2;
  ELSE B := 0;
  END IF;

  -- Characteristic frequency f1
  IF f < 100 AND (isCargo OR isTanker) THEN f1 := 600.0/Vc;
  ELSE f1 := 480.0/Vc;
  END IF;

  -- Parameter D
  IF f < 100 AND isCargo THEN D := 0.8;
  ELSIF f < 100 AND isTanker THEN D := 1.0;
  ELSIF isCruise THEN D := 4.0;
  ELSE D := 3.0;
  END IF;

  -- MacGillivray & de Jong source level formulation
  term1 := K - 10.0 * (B + 2.0) * LOG10(f1); 
  term2 :=  5.0 * B * LOG10(f);
  term3 := -10.0 * LOG10(POWER(1.0 - POWER(f/f1, 0.5*(B+2)), 2) + POWER(D,2));

  -- Enforce minimum modelling speed of 3 knots
  IF Vref < 3 THEN Vref:=3;
  END IF;

  term4 := 60.0 * LOG10(Vref / Vc);
  term5 := 20.0 * LOG10(LOAref / 91.44);  -- 91.44 m = reference LOA
  term6 := 10.0 * LOG10(0.231 * f);

  SL := term1 + term2 + term3 + term4 + term5 + term6;

  -- Empirical correction for vessels idling inside ports
  IF isCruise OR isCargo OR isTanker THEN
    IF InPort AND Speed < 0.5 THEN 
      SL := SL - 15;   -- subtract 15 dB
    END IF;
  END IF;

  RETURN SL;
END;
$$;

\echo == vessels of the day with a known class and length
DROP TABLE IF EXISTS Vessel;
CREATE TABLE Vessel AS
WITH T AS (
  SELECT MMSI, ShipType, count(*) AS n FROM AISNoJump
  WHERE ShipType NOT IN ('Undefined','Spare 1','Spare 2','Reserved','WIG','Not party to conflict')
  GROUP BY MMSI, ShipType ),
Typ AS (SELECT DISTINCT ON (MMSI) MMSI, ShipType FROM T ORDER BY MMSI, n DESC, ShipType),
Len AS (SELECT MMSI, max(Length) AS Length FROM AISNoJump WHERE Length > 0 GROUP BY MMSI),
Code AS (
  SELECT MMSI, ShipType, Length, CASE ShipType
    WHEN 'Pilot' THEN 50 WHEN 'SAR' THEN 51 WHEN 'Tug' THEN 52 WHEN 'Port tender' THEN 53
    WHEN 'Anti-pollution' THEN 54 WHEN 'Law enforcement' THEN 55 WHEN 'Fishing' THEN 30
    WHEN 'Towing' THEN 31 WHEN 'Towing long/wide' THEN 32 WHEN 'Dredging' THEN 33
    WHEN 'Diving' THEN 34 WHEN 'Military' THEN 35 WHEN 'Sailing' THEN 36 WHEN 'Pleasure' THEN 37
    WHEN 'HSC' THEN 40 WHEN 'Passenger' THEN 60 WHEN 'Cargo' THEN 70 WHEN 'Tanker' THEN 80
    WHEN 'Other' THEN 90 END AS ShipTypeCode
  FROM Typ JOIN Len USING (MMSI) )
SELECT *, CASE ShipTypeCode
    WHEN 50 THEN 3 WHEN 51 THEN 6 WHEN 52 THEN 3 WHEN 53 THEN 3 WHEN 54 THEN 11 WHEN 55 THEN 6
    WHEN 30 THEN 2 WHEN 31 THEN 3 WHEN 32 THEN 3 WHEN 33 THEN 4 WHEN 34 THEN 11 WHEN 35 THEN 5
    WHEN 36 THEN 1 WHEN 37 THEN 1 WHEN 40 THEN 7 WHEN 60 THEN 7 WHEN 70 THEN 9 WHEN 80 THEN 10
    WHEN 90 THEN 11 END AS VesselClassCode
FROM Code WHERE ShipTypeCode IS NOT NULL;
SELECT count(*) AS vessels FROM Vessel;

\echo == vessels under way outside the ports, and the range of their source level (1555 | 106.4 | 195.4)
DROP TABLE IF EXISTS ShipNoise;
CREATE TABLE ShipNoise AS
WITH SL AS (
  SELECT a.MMSI, tfloatSeqSetGaps(array_agg(tfloat(
      ComputeSL(v.VesselClassCode, 63.0, a.SOG,
        ComputeVc(v.VesselClassCode, v.ShipTypeCode, a.SOG, v.Length), v.Length, false),
      a.T) ORDER BY a.T), interval '3 minutes') AS SL
  FROM AISNoJump a JOIN Vessel v USING (MMSI)
  WHERE a.SOG > 3 AND a.SOG <= 40
  GROUP BY a.MMSI ),
Tr AS (
  SELECT s.MMSI, minusGeometry(atTime(h.Trip, getTime(s.SL)), p.Geom) AS Trip, s.SL
  FROM SL s JOIN Ships h USING (MMSI), PortAreas p )
SELECT MMSI, Trip, atTime(SL, getTime(Trip)) AS SL FROM Tr WHERE Trip IS NOT NULL;
DELETE FROM ShipNoise WHERE SL IS NULL;
SELECT count(*) AS noisy, round(min(minValue(SL))::numeric,1), round(max(maxValue(SL))::numeric,1) FROM ShipNoise;

\echo == Listing: the radius of the noise from the excess level and the depth
-- Radius of the noise of a vessel from the excess level DL = SL - NL and the depth H,
-- in meters, capped at 10 km. Spherical: 10^(DL/20). Where H >= 10 and 10^(DL/20) > 10 H,
-- the depth-limited law: 10^((DL - 5 log10(10 H))/15).
CREATE OR REPLACE FUNCTION noiseRadius(DL tfloat, Depth tfloat)
RETURNS tfloat LANGUAGE sql AS $$
  WITH Law AS (
    SELECT (DL #> 20 * log10(10 * Depth)) & (Depth #>= 10) AS Shallow ),
  Exponent AS (
    SELECT CASE WHEN Shallow IS NULL OR NOT (Shallow ?= true) THEN DL / 20
      ELSE merge(atTime(DL / 20, getTime(DL) - whenTrue(Shallow)),
        atTime((DL - 5 * log10(10 * Depth)) / 15, whenTrue(Shallow))) END AS E
    FROM Law ),
  Capped AS (
    SELECT CASE WHEN NOT ((E #>= 4) ?= true) THEN E
      ELSE merge(atSpan(E, floatspan '[-10, 4)'), tfloat(4.0, whenTrue(E #>= 4))) END AS E
    FROM Exponent )
  SELECT exp(E * ln(10)) FROM Capped
$$;

\echo == Listing: the radius of the fishing vessel with and without the depth
-- 165.8 | 378.2 | 01:06:41.329226 | 01:41:15.027631
DROP TABLE IF EXISTS NoiseOne;
CREATE TABLE NoiseOne AS
WITH Depth AS (
  SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
  FROM ShipNoise s, Bathymetry b
  WHERE s.MMSI = 220334000 AND ST_Intersects(b.Rast, trajectory(s.Trip))
  GROUP BY s.MMSI )
SELECT s.MMSI, s.Trip, s.SL, d.Depth,
  tcbuffer(s.Trip, noiseRadius(s.SL - 80, NULL)) AS Spherical,
  tcbuffer(s.Trip, noiseRadius(s.SL - 80, d.Depth)) AS DepthAware
FROM ShipNoise s JOIN Depth d USING (MMSI);
SELECT round((ST_Area(traversedArea(Spherical, true)) / 1e6)::numeric, 1) AS AreaSph,
  round((ST_Area(traversedArea(DepthAware, true)) / 1e6)::numeric, 1) AS AreaDepth,
  duration(whenTrue(tIntersects(Spherical, n.Geom))) AS InReefSph,
  duration(whenTrue(tIntersects(DepthAware, n.Geom))) AS InReefDepth
FROM NoiseOne, NaturalAreas n
WHERE n.Id = 22;

\echo == Listing: the ambient noise level of the fishing vessel with the wind
-- 2.6 | 5.4 | 80.1 | 80.3 | 360.3
WITH Wind AS (
  SELECT mergeAgg(rasterValue(atTime(s.Trip, w.ValidTime), w.Rast)
    ORDER BY w.ValidTime) AS Wind
  FROM ShipNoise s, WindSpeed w
  WHERE s.MMSI = 220334000 AND s.Trip && w.ValidTime AND
    ST_Intersects(w.Rast, trajectory(s.Trip)) ),
Level AS (
  SELECT Wind, 10 * log10(1e8 + exp(ln(10) / 10 * (50 + 7.5 * exp(0.5 * ln(Wind)) +
    20 * log10(0.063) - 40 * log10(0.463) + 10 * log10(0.231 * 63)))) AS NL
  FROM Wind )
SELECT round(minValue(Wind)::numeric, 1) AS MinWind, round(maxValue(Wind)::numeric, 1) AS MaxWind,
  round(minValue(NL)::numeric, 1) AS MinNL, round(maxValue(NL)::numeric, 1) AS MaxNL,
  round((ST_Area(traversedArea(tcbuffer(o.Trip, noiseRadius(o.SL - l.NL, o.Depth)), true))
    / 1e6)::numeric, 1) AS AreaWind
FROM Level l, NoiseOne o;

\echo == the three moving regions of the noise of every vessel
DROP TABLE IF EXISTS ShipDepth;
CREATE TABLE ShipDepth AS
SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, b.Rast)) AS Depth
FROM ShipNoise s, Bathymetry b
WHERE ST_Intersects(b.Rast, trajectory(s.Trip))
GROUP BY s.MMSI;

DROP TABLE IF EXISTS WindNoise;
CREATE TABLE WindNoise AS
WITH Wind AS (
  SELECT s.MMSI, mergeAgg(rasterValue(atTime(s.Trip, w.ValidTime), w.Rast)
    ORDER BY w.ValidTime) AS Wind
  FROM ShipNoise s, WindSpeed w
  WHERE s.Trip && w.ValidTime AND ST_Intersects(w.Rast, trajectory(s.Trip))
  GROUP BY s.MMSI )
SELECT MMSI, Wind,
  10 * log10(1e8 + exp(ln(10) / 10 * (50 + 7.5 * exp(0.5 * ln(Wind)) +
    20 * log10(0.063) - 40 * log10(0.463) + 10 * log10(0.231 * 63)))) AS NL
FROM Wind;

DROP TABLE IF EXISTS NoiseModels;
CREATE TABLE NoiseModels AS
SELECT s.MMSI, s.Trip, d.Depth,
  CASE WHEN w.NL IS NULL THEN s.SL - 80
  ELSE merge(atTime(s.SL - 80, getTime(s.Trip) - getTime(w.NL)), s.SL - w.NL) END AS DLWind
FROM ShipNoise s LEFT JOIN ShipDepth d USING (MMSI) LEFT JOIN WindNoise w USING (MMSI);
ALTER TABLE NoiseModels ADD COLUMN Spherical tcbuffer, ADD COLUMN DepthAware tcbuffer,
  ADD COLUMN DepthWind tcbuffer;
UPDATE NoiseModels n SET
  Spherical = tcbuffer(n.Trip, noiseRadius(s.SL - 80, NULL)),
  DepthAware = tcbuffer(n.Trip, noiseRadius(s.SL - 80, n.Depth)),
  DepthWind = tcbuffer(n.Trip, noiseRadius(n.DLWind, n.Depth))
FROM ShipNoise s WHERE s.MMSI = n.MMSI;
CREATE INDEX ON NoiseModels USING gist (Spherical);
CREATE INDEX ON NoiseModels USING gist (DepthAware);
CREATE INDEX ON NoiseModels USING gist (DepthWind);
ANALYZE NoiseModels;

\echo == pairs of a vessel and a protected area its noise may reach under some model
DROP TABLE IF EXISTS NoisePairs;
CREATE TABLE NoisePairs AS
SELECT x.MMSI, n.Id AS AreaId,
  eIntersects(n.Geom, x.Spherical) AS Spherical,
  eIntersects(n.Geom, x.DepthAware) AS DepthAware,
  eIntersects(n.Geom, x.DepthWind) AS DepthWind
FROM NoiseModels x, NaturalAreas n
WHERE x.Spherical && stbox(n.Geom) OR x.DepthAware && stbox(n.Geom)
  OR x.DepthWind && stbox(n.Geom);

\echo == vessels, vessels over the bathymetry, and vessels for which the depth law applies at some instant (1555 | 974 | 946)
SELECT count(*) AS Vessels, count(Depth) AS OverBathy,
  count(*) FILTER (WHERE ((SL80 #> 20 * log10(10 * Depth)) & (Depth #>= 10)) ?= true) AS DepthMatters
FROM (SELECT n.*, s.SL - 80 AS SL80 FROM NoiseModels n JOIN ShipNoise s USING (MMSI)) t;

\echo == Table: pairs reached under the three models, the pairs and areas the depth adds, and the pairs gained and lost with both fields (6628 | 6992 | 6985 | 364 | 146 | 359 | 2)
SELECT count(*) FILTER (WHERE Spherical) AS Spherical,
  count(*) FILTER (WHERE DepthAware) AS DepthAware,
  count(*) FILTER (WHERE DepthWind) AS DepthWind,
  count(*) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthGained,
  count(DISTINCT AreaId) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthGainedAreas,
  count(*) FILTER (WHERE DepthWind AND NOT Spherical) AS EnvGained,
  count(*) FILTER (WHERE Spherical AND NOT DepthWind) AS EnvLost
FROM NoisePairs;

\echo == the fishing vessel: type, length, period under way, sequences, km, source level, time over the bathymetry, depth (Fishing | 15 | 05:29:12 | 17:16:58 | 7 | 44.6 | 121.0 | 148.5 | 03:09:05.740078 | 0.3 | 60.7)
\set m 220334000
SELECT v.ShipType, v.Length, startTimestamp(x.Trip) AS StartT, endTimestamp(x.Trip) AS EndT,
  numSequences(x.Trip) AS Seqs, round((length(x.Trip) / 1000)::numeric, 1) AS Km,
  round(minValue(s.SL)::numeric, 1) AS MinSL, round(maxValue(s.SL)::numeric, 1) AS MaxSL,
  duration(getTime(x.Depth)) AS DepthKnown,
  round(minValue(x.Depth)::numeric, 1) AS MinDepth, round(maxValue(x.Depth)::numeric, 1) AS MaxDepth
FROM NoiseModels x JOIN Vessel v USING (MMSI) JOIN ShipNoise s USING (MMSI) WHERE x.MMSI = :m;

\echo == nearest port to the start and to the end of its trip (Vesterø Havn, Læsø, 11719 m and 11723 m)
SELECT 'start' AS k, p.PortName, round(ST_Distance(p.Geom, startValue(x.Trip))::numeric) AS d
FROM NoiseModels x, Port p WHERE x.MMSI = :m ORDER BY ST_Distance(p.Geom, startValue(x.Trip)) LIMIT 1;
SELECT 'end' AS k, p.PortName, round(ST_Distance(p.Geom, endValue(x.Trip))::numeric) AS d
FROM NoiseModels x, Port p WHERE x.MMSI = :m ORDER BY ST_Distance(p.Geom, endValue(x.Trip)) LIMIT 1;

\echo == time under the depth law, time at the cap of 10 km, largest radius spherical and depending on the depth (01:49:36.313068 | | 2650 | 7611)
WITH r AS (SELECT s.SL - 80 AS DL, x.Depth, x.Trip FROM NoiseModels x JOIN ShipNoise s USING (MMSI) WHERE x.MMSI = :m)
SELECT duration(whenTrue((DL #> 20 * log10(10 * Depth)) & (Depth #>= 10))) AS DepthLaw,
  duration(whenTrue(noiseRadius(DL, Depth) #>= 9999.999)) AS AtCap,
  round(maxValue(noiseRadius(DL, NULL))::numeric) AS MaxRSph,
  round(maxValue(noiseRadius(DL, Depth))::numeric) AS MaxRDep
FROM r;

\echo == wind and ambient noise met by the fishing vessel (2.6 | 5.4 | 80.1 | 80.3)
SELECT round(minValue(Wind)::numeric, 1) AS MinWind, round(maxValue(Wind)::numeric, 1) AS MaxWind,
  round(minValue(NL)::numeric, 1) AS MinNL, round(maxValue(NL)::numeric, 1) AS MaxNL
FROM WindNoise WHERE MMSI = :m;

\echo == time the noise spends in each protected area it reaches under the three models (reef area 22: 01:06:41.329226 | 01:41:15.027631; area 35 only with the depth, 00:05:53.168909)
SELECT n.Id, n.NameEng, n.DesigEng,
  duration(whenTrue(tIntersects(x.Spherical, n.Geom))) AS Sph,
  duration(whenTrue(tIntersects(x.DepthAware, n.Geom))) AS Dep,
  duration(whenTrue(tIntersects(x.DepthWind, n.Geom))) AS Env
FROM NoiseModels x, NaturalAreas n
WHERE x.MMSI = :m AND eIntersects(n.Geom, x.DepthAware)
ORDER BY 5 DESC;
