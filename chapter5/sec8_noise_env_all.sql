-- Section 8: underwater noise of every trip of the day depending on two fields,
-- the depth of the water (Bathymetry) and the 10 m wind speed of ERA5
-- (WindSpeed, hourly). The ambient noise level is the energy sum of the 80 dB
-- of the sea cells and the noise of the wind in the one-third octave band of
-- 63 Hz, 50 + 7.5 sqrt(w) + 20 log10(f) - 40 log10(f + 0.4) with f = 0.063 kHz
-- (spectral density, Coates as given by Stojanovic), plus 10 log10(0.231 * 63)
-- for the bandwidth. Spreading depends on the depth as in
-- sec8_noise_depth_all.sql. Requires the table NoiseDepth of that script.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS NoiseEnv;
CREATE TABLE NoiseEnv AS
WITH Wind AS (
  SELECT v.MMSI, v.TripId, mergeAgg(rasterValue(atTime(v.Trip, w.ValidTime), w.Rast)
    ORDER BY w.ValidTime) AS Wind
  FROM VesselTrip v, WindSpeed w
  WHERE v.Trip && w.ValidTime AND ST_Intersects(w.Rast, v.Trajectory)
  GROUP BY v.MMSI, v.TripId ),
Ambient AS (
  SELECT MMSI, TripId, Wind,
    10 * log10(1e8 + exp(ln(10) / 10 * (50 + 7.5 * exp(0.5 * ln(Wind))
      + 20 * log10(0.063) - 40 * log10(0.463) + 10 * log10(0.231 * 63)))) AS NL
  FROM Wind ),
Depth AS (
  SELECT v.MMSI, v.TripId, mergeAgg(rasterValue(v.Trip, b.Rast)) AS Depth
  FROM VesselTrip v, Bathymetry b
  WHERE ST_Intersects(b.Rast, v.Trajectory)
  GROUP BY v.MMSI, v.TripId ),
Level AS (
  SELECT v.MMSI, v.TripId, v.Trip, d.Depth,
    CASE WHEN a.NL IS NULL THEN v.SL - 80
    ELSE merge(atTime(v.SL - 80, getTime(v.Trip) - getTime(a.NL)), v.SL - a.NL) END AS DL
  FROM VesselTrip v LEFT JOIN Ambient a USING (MMSI, TripId)
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

\echo == trip-area pairs reached by the noise under the three models
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
