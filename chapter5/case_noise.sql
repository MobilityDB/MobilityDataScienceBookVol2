-- Case study, Underwater Noise and the Depth of the Water: the noise of the
-- vessels of the day of the chapter (2026-01-20) under spherical spreading, under
-- spreading depending on the depth of the bathymetry, and under spreading
-- depending on the depth with the ambient noise raised by the wind of ERA5, and
-- the protected areas the noise reaches under the three models. It reads the
-- tables AISClean and Ships of the AIS database of the book, Port, NaturalAreas,
-- Bathymetry, and WindSpeed of load_all.sh, and the functions ComputeVc and
-- ComputeSL and the tables VesselClass and PortAreas of chapter 3, which
-- chapter3/ships_noise.sql creates and which must run first. The source level of
-- a vessel is computed at 63 Hz at the reports whose speed exceeds 3 knots, over
-- the periods in which the column Noise of Ships, the noise of chapter 3, is
-- defined: under way, outside the port areas. Each listing of the chapter is
-- preceded by its printed answer; the other queries give the numbers stated in
-- the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == vessels under way outside the ports, and the range of their source level (1499 | 106.4 | 191.7)
DROP TABLE IF EXISTS ShipNoise;
CREATE TABLE ShipNoise AS
WITH SL AS (
  SELECT a.MMSI, tfloatSeqSetGaps(array_agg(tfloat(
      ComputeSL(v.VesselClassCode, 63.0, a.SOG,
        ComputeVc(v.VesselClassCode, v.ShipTypeCode, a.SOG, v.Length), v.Length, false),
      a.T) ORDER BY a.T), interval '600 s') AS SL
  FROM AISClean a JOIN VesselClass v USING (MMSI)
  WHERE a.SOG > 3 AND a.SOG <= 40
  GROUP BY a.MMSI )
SELECT s.MMSI, tgeompoint(s.Noise) AS Trip, atTime(l.SL, getTime(s.Noise)) AS SL
FROM Ships s JOIN SL l USING (MMSI)
WHERE s.Noise IS NOT NULL;
SELECT COUNT(*) AS Noisy, round(MIN(minValue(SL))::numeric, 1) AS MinSL,
  round(MAX(maxValue(SL))::numeric, 1) AS MaxSL
FROM ShipNoise;
\echo == the vessels with the smallest and the largest source level: type and length (Pleasure | 7 | 106.4, Pilot | 12 | 191.7)
(SELECT v.ShipType, v.Length, round(minValue(s.SL)::numeric, 1) AS SL
  FROM ShipNoise s JOIN VesselClass v USING (MMSI) ORDER BY minValue(s.SL) LIMIT 1)
UNION ALL
(SELECT v.ShipType, v.Length, round(maxValue(s.SL)::numeric, 1)
  FROM ShipNoise s JOIN VesselClass v USING (MMSI) ORDER BY maxValue(s.SL) DESC LIMIT 1);

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

\echo == Listing: the depth, the wind, and the three moving regions of the noise of every vessel
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
WITH Excess AS (
  SELECT s.MMSI, s.Trip, d.Depth, s.SL - 80 AS DL,
    CASE WHEN w.NL IS NULL THEN s.SL - 80
    ELSE merge(atTime(s.SL - 80, getTime(s.Trip) - getTime(w.NL)), s.SL - w.NL)
    END AS DLWind
  FROM ShipNoise s LEFT JOIN ShipDepth d USING (MMSI)
    LEFT JOIN WindNoise w USING (MMSI) )
SELECT MMSI, Trip, Depth,
  tcbuffer(Trip, noiseRadius(DL, NULL)) AS Spherical,
  tcbuffer(Trip, noiseRadius(DL, Depth)) AS DepthAware,
  tcbuffer(Trip, noiseRadius(DLWind, Depth)) AS DepthWind
FROM Excess;
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

\echo == vessels, vessels over the bathymetry, and vessels for which the depth law applies at some instant (1499 | 972 | 944)
SELECT COUNT(*) AS Vessels, COUNT(Depth) AS OverBathy,
  COUNT(*) FILTER (WHERE ((SL80 #> 20 * log10(10 * Depth)) & (Depth #>= 10)) ?= true) AS DepthMatters
FROM (SELECT n.*, s.SL - 80 AS SL80 FROM NoiseModels n JOIN ShipNoise s USING (MMSI)) t;

\echo == Table: pairs reached under the three models, the pairs and areas the depth adds, the pairs gained and lost with both fields, and the pairs reached with the depth that the wind loses (6628 | 6991 | 6984 | 363 | 146 | 358 | 2 | 7)
SELECT COUNT(*) FILTER (WHERE Spherical) AS Spherical,
  COUNT(*) FILTER (WHERE DepthAware) AS DepthAware,
  COUNT(*) FILTER (WHERE DepthWind) AS DepthWind,
  COUNT(*) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthGained,
  COUNT(DISTINCT AreaId) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthGainedAreas,
  COUNT(*) FILTER (WHERE DepthWind AND NOT Spherical) AS EnvGained,
  COUNT(*) FILTER (WHERE Spherical AND NOT DepthWind) AS EnvLost,
  COUNT(*) FILTER (WHERE DepthAware AND NOT DepthWind) AS WindLost
FROM NoisePairs;

\echo == the fishing vessel: type, length, period under way, sequences, km, source level, time over the bathymetry, depth (Fishing | 15 | 05:29:12 | 17:16:58 | 5 | 45.2 | 121.0 | 148.5 | 03:14:05.740078 | 0.3 | 60.7)
\set m 220334000
SELECT v.ShipType, v.Length, startTimestamp(x.Trip) AS StartT, endTimestamp(x.Trip) AS EndT,
  numSequences(x.Trip) AS Seqs, round((length(x.Trip) / 1000)::numeric, 1) AS Km,
  round(minValue(s.SL)::numeric, 1) AS MinSL, round(maxValue(s.SL)::numeric, 1) AS MaxSL,
  duration(getTime(x.Depth)) AS DepthKnown,
  round(minValue(x.Depth)::numeric, 1) AS MinDepth, round(maxValue(x.Depth)::numeric, 1) AS MaxDepth
FROM NoiseModels x JOIN VesselClass v USING (MMSI) JOIN ShipNoise s USING (MMSI) WHERE x.MMSI = :m;

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

\echo == the fishing vessel: time under way, and time its trajectory spends in the reef area 22 (03:33:01 | 00:17:12.959115)
SELECT duration(getTime(x.Trip)) AS Underway,
  duration(whenTrue(tIntersects(x.Trip, n.Geom))) AS InReef
FROM NoiseModels x, NaturalAreas n
WHERE x.MMSI = :m AND n.Id = 22;

\echo == the wind of the day over the area: mean and highest wind speed (5.5 | 16.5)
SELECT round((ST_SummaryStatsAgg(Rast, 1, true)).mean::numeric, 1) AS MeanWind,
  round((ST_SummaryStatsAgg(Rast, 1, true)).max::numeric, 1) AS MaxWind
FROM WindSpeed;

\echo == along the trips: highest wind and ambient noise, and vessels whose ambient noise exceeds 81 dB (14.1 | 82.6 | 181)
SELECT round(MAX(maxValue(Wind))::numeric, 1) AS MaxWind,
  round(MAX(maxValue(NL))::numeric, 1) AS MaxNL,
  COUNT(*) FILTER (WHERE maxValue(NL) > 81) AS Over81
FROM WindNoise;
