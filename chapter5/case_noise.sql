-- Case study, Underwater Noise and the Depth of the Water. Runs on the database
-- of chapter 3 (AIS day 2025-01-01, table VesselTrip built by the loader of that
-- chapter) with the tables Bathymetry and WindSpeed of that day added, as the
-- README states. SL is the source level of a trip and 80 dB the ambient noise of
-- the sea cells. Where the water is at least 10 m deep and the spherical radius
-- exceeds 10 H, the radius is 10^((SL - NL - 5 log10(10 H))/15); elsewhere it is
-- 10^((SL - NL)/20); it is capped at 10 km. The wind adds to the ambient noise
-- the band level 50 + 7.5 sqrt(w) + 20 log10(f) - 40 log10(f + 0.4) with
-- f = 0.063 kHz, plus 10 log10(0.231 * 63) for the one-third octave band of 63 Hz.
-- Each listing of the chapter is preceded by its printed answer; the other
-- queries give the numbers stated in the text.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == Query: the noise of the fishing vessel of chapter 3 with spreading depending on the depth
-- 01:22:20.905166 | 204.2 | 624.4
DROP TABLE IF EXISTS NoiseDepthOne;
CREATE TABLE NoiseDepthOne AS
WITH Trip AS (
  SELECT MMSI, TripId, Trip, SL, Noise
  FROM VesselTrip WHERE MMSI = 219013538 AND TripId = 1 ),
Depth AS (
  SELECT t.MMSI, t.TripId, mergeAgg(rasterValue(t.Trip, b.Rast)) AS Depth
  FROM Trip t, Bathymetry b
  WHERE ST_Intersects(b.Rast, trajectory(t.Trip))
  GROUP BY t.MMSI, t.TripId ),
Regime AS (
  SELECT t.*, d.Depth,
    ((t.SL - 80) #> 20 * log10(10 * d.Depth)) & (d.Depth #>= 10) AS Stripping
  FROM Trip t JOIN Depth d USING (MMSI, TripId) ),
Exponent AS (
  SELECT *, merge(
      atTime((SL - 80) / 20, getTime(Trip) - whenTrue(Stripping)),
      atTime((SL - 80 - 5 * log10(10 * Depth)) / 15, whenTrue(Stripping))) AS E
  FROM Regime ),
Capped AS (
  SELECT *, merge(atSpan(E, floatspan '[-10, 4)'),
    tfloat(4.0, whenTrue(E #>= 4))) AS EC
  FROM Exponent )
SELECT MMSI, TripId, Trip, Noise, Stripping, Depth,
  tcbuffer(Trip, exp(EC * ln(10))) AS NoiseDepth
FROM Capped;
SELECT duration(whenTrue(Stripping)) AS DepthTime,
  round((ST_Area(traversedArea(Noise, true)) / 1e6)::numeric, 1) AS Area,
  round((ST_Area(traversedArea(NoiseDepth, true)) / 1e6)::numeric, 1) AS AreaDepth
FROM NoiseDepthOne;
\echo == time over the bathymetry (05:15), and time with the radius at the cap of 10 km (39 minutes)
SELECT duration(getTime(n.Depth)) AS DepthKnown,
  duration(whenTrue(merge(
    atTime((v.SL - 80) / 20, getTime(n.Trip) - whenTrue(n.Stripping)),
    atTime((v.SL - 80 - 5 * log10(10 * n.Depth)) / 15, whenTrue(n.Stripping))) #>= 4))
    AS CappedTime
FROM NoiseDepthOne n JOIN VesselTrip v USING (MMSI, TripId);
\echo == time the noise spends in each protected area it reaches, spherical and depending on the depth
SELECT n.Id, n.NameEng,
  duration(whenTrue(tIntersects(r.Noise, n.Geom))) AS Spherical,
  duration(whenTrue(tIntersects(r.NoiseDepth, n.Geom))) AS DepthAware
FROM NoiseDepthOne r, NaturalAreas n
WHERE eIntersects(n.Geom, r.NoiseDepth)
ORDER BY 4 DESC;

\echo == Listing: the ambient noise level along the trips from the wind of ERA5
DROP TABLE IF EXISTS WindNoise;
CREATE TABLE WindNoise AS
WITH Wind AS (
  SELECT v.MMSI, v.TripId, mergeAgg(rasterValue(atTime(v.Trip, w.ValidTime),
    w.Rast) ORDER BY w.ValidTime) AS Wind
  FROM VesselTrip v, WindSpeed w
  WHERE v.Trip && w.ValidTime AND ST_Intersects(w.Rast, v.Trajectory)
  GROUP BY v.MMSI, v.TripId )
SELECT MMSI, TripId, Wind,
  10 * log10(1e8 + exp(ln(10) / 10 * (50 + 7.5 * exp(0.5 * ln(Wind)) +
    20 * log10(0.063) - 40 * log10(0.463) + 10 * log10(0.231 * 63)))) AS NL
FROM Wind;
\echo == wind and ambient noise met by the fishing vessel (7.1 to 13.1 m/s, 80.5 to 82.2 dB)
SELECT round(minValue(Wind)::numeric, 1) AS MinWind, round(maxValue(Wind)::numeric, 1) AS MaxWind,
  round(minValue(NL)::numeric, 1) AS MinNL, round(maxValue(NL)::numeric, 1) AS MaxNL
FROM WindNoise WHERE MMSI = 219013538 AND TripId = 1;
\echo == highest wind of the day in the ERA5 field (21.5 m/s)
SELECT round((ST_SummaryStatsAgg(Rast, 1, true)).max::numeric, 1) AS MaxWind FROM WindSpeed;

\echo == the noise of every trip with spreading depending on the depth
DROP TABLE IF EXISTS NoiseDepth;
CREATE TABLE NoiseDepth AS
WITH Depth AS (
  SELECT v.MMSI, v.TripId, mergeAgg(rasterValue(v.Trip, b.Rast)) AS Depth
  FROM VesselTrip v, Bathymetry b
  WHERE ST_Intersects(b.Rast, v.Trajectory)
  GROUP BY v.MMSI, v.TripId ),
Regime AS (
  SELECT v.MMSI, v.TripId, v.Trip, v.SL, v.Noise,
    ((v.SL - 80) #> 20 * log10(10 * d.Depth)) & (d.Depth #>= 10) AS Stripping,
    d.Depth
  FROM VesselTrip v LEFT JOIN Depth d USING (MMSI, TripId) ),
Exponent AS (
  SELECT MMSI, TripId, Trip, Noise, Stripping,
    CASE WHEN Stripping IS NULL OR NOT (Stripping ?= true) THEN (SL - 80) / 20
    ELSE merge(
      atTime((SL - 80) / 20, getTime(Trip) - whenTrue(Stripping)),
      atTime((SL - 80 - 5 * log10(10 * Depth)) / 15, whenTrue(Stripping))) END AS E
  FROM Regime ),
Capped AS (
  SELECT MMSI, TripId, Trip, Noise, Stripping,
    CASE WHEN NOT ((E #>= 4) ?= true) THEN E
    ELSE merge(atSpan(E, floatspan '[-10, 4)'), tfloat(4.0, whenTrue(E #>= 4))) END AS EC
  FROM Exponent )
SELECT MMSI, TripId, Trip, Noise, Stripping,
  tcbuffer(Trip, exp(EC * ln(10))) AS NoiseDepth
FROM Capped;
CREATE INDEX NoiseDepth_Noise_Idx ON NoiseDepth USING gist (Noise);
CREATE INDEX NoiseDepth_NoiseDepth_Idx ON NoiseDepth USING gist (NoiseDepth);
ANALYZE NoiseDepth;
\echo == trips, and trips whose spreading depends on the depth at some time (2111 | 577)
SELECT count(*) AS Trips, count(*) FILTER (WHERE Stripping ?= true) AS DepthTrips
FROM NoiseDepth;
\echo == pairs reached with spherical spreading and depending on the depth, and the pairs and areas the depth adds (4147 | 4334 | 191 | 103)
SELECT count(*) FILTER (WHERE Spherical) AS Spherical,
  count(*) FILTER (WHERE DepthAware) AS DepthAware,
  count(*) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthOnly,
  count(DISTINCT AreaId) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthOnlyAreas
FROM (
  SELECT n.Id AS AreaId, eIntersects(n.Geom, x.Noise) AS Spherical,
    eIntersects(n.Geom, x.NoiseDepth) AS DepthAware
  FROM NoiseDepth x, NaturalAreas n
  WHERE x.NoiseDepth && stbox(n.Geom) ) t;

\echo == the noise of every trip depending on the depth and on the wind
DROP TABLE IF EXISTS NoiseEnv;
CREATE TABLE NoiseEnv AS
WITH Depth AS (
  SELECT v.MMSI, v.TripId, mergeAgg(rasterValue(v.Trip, b.Rast)) AS Depth
  FROM VesselTrip v, Bathymetry b
  WHERE ST_Intersects(b.Rast, v.Trajectory)
  GROUP BY v.MMSI, v.TripId ),
Level AS (
  SELECT v.MMSI, v.TripId, v.Trip, d.Depth,
    CASE WHEN a.NL IS NULL THEN v.SL - 80
    ELSE merge(atTime(v.SL - 80, getTime(v.Trip) - getTime(a.NL)), v.SL - a.NL) END AS DL
  FROM VesselTrip v LEFT JOIN WindNoise a USING (MMSI, TripId)
    LEFT JOIN Depth d USING (MMSI, TripId) ),
Regime AS (
  SELECT *, (DL #> 20 * log10(10 * Depth)) & (Depth #>= 10) AS Stripping
  FROM Level ),
Exponent AS (
  SELECT MMSI, TripId, Trip, Stripping,
    CASE WHEN Stripping IS NULL OR NOT (Stripping ?= true) THEN DL / 20
    ELSE merge(
      atTime(DL / 20, getTime(Trip) - whenTrue(Stripping)),
      atTime((DL - 5 * log10(10 * Depth)) / 15, whenTrue(Stripping))) END AS E
  FROM Regime ),
Capped AS (
  SELECT MMSI, TripId, Trip, Stripping,
    CASE WHEN NOT ((E #>= 4) ?= true) THEN E
    ELSE merge(atSpan(E, floatspan '[-10, 4)'), tfloat(4.0, whenTrue(E #>= 4))) END AS EC
  FROM Exponent )
SELECT MMSI, TripId, Trip, Stripping, tcbuffer(Trip, exp(EC * ln(10))) AS NoiseEnv
FROM Capped;
CREATE INDEX NoiseEnv_NoiseEnv_Idx ON NoiseEnv USING gist (NoiseEnv);
ANALYZE NoiseEnv;
\echo == area of the noise of the fishing vessel with both fields (596.5 km2)
SELECT round((ST_Area(traversedArea(NoiseEnv, true)) / 1e6)::numeric, 1) AS AreaEnv
FROM NoiseEnv WHERE MMSI = 219013538 AND TripId = 1;
\echo == Table: pairs reached under the three models, and the pairs gained and lost with both fields (4147 | 4334 | 4263 | 30 | 146)
SELECT count(*) FILTER (WHERE Spherical) AS Spherical,
  count(*) FILTER (WHERE DepthAware) AS DepthAware,
  count(*) FILTER (WHERE EnvAware) AS DepthWind,
  count(*) FILTER (WHERE Spherical AND NOT EnvAware) AS LostWithWind,
  count(*) FILTER (WHERE EnvAware AND NOT Spherical) AS GainedWithEnv
FROM (
  SELECT eIntersects(n.Geom, x.Noise) AS Spherical,
    eIntersects(n.Geom, x.NoiseDepth) AS DepthAware,
    eIntersects(n.Geom, e.NoiseEnv) AS EnvAware
  FROM NoiseDepth x JOIN NoiseEnv e USING (MMSI, TripId), NaturalAreas n
  WHERE (x.NoiseDepth && stbox(n.Geom) OR x.Noise && stbox(n.Geom)
    OR e.NoiseEnv && stbox(n.Geom)) ) t;
