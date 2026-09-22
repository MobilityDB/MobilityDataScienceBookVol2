-- Section 8: underwater noise with spreading depending on the depth of the water
-- for every trip of the day, and the protected areas its noise reaches compared
-- with spherical spreading. SL is the source level (dB) and NL = 80 dB the
-- ambient noise of every sea cell. Where the water is at least 10 m deep and the
-- spherical radius exceeds 10 H, the radius is 10^((SL - NL - 5 log10(10 H))/15);
-- elsewhere it is 10^((SL - NL)/20); it is capped at 10 km. A trip that crosses no
-- tile of the bathymetry keeps its spherical noise.
\pset footer off
\timing on
SET TimeZone = 'UTC';

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

\echo == trips, and trips whose spreading depends on the depth at some time
SELECT count(*) AS Trips, count(*) FILTER (WHERE Stripping ?= true) AS DepthTrips
FROM NoiseDepth;

\echo == trip-area pairs reached by the noise, spherical and depth-aware
SELECT count(*) FILTER (WHERE Spherical) AS Spherical,
  count(*) FILTER (WHERE DepthAware) AS DepthAware,
  count(*) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthOnly,
  count(DISTINCT AreaId) FILTER (WHERE DepthAware AND NOT Spherical) AS DepthOnlyAreas
FROM (
  SELECT n.Id AS AreaId, eIntersects(n.Geom, x.Noise) AS Spherical,
    eIntersects(n.Geom, x.NoiseDepth) AS DepthAware
  FROM NoiseDepth x, NaturalAreas n
  WHERE x.NoiseDepth && stbox(n.Geom) ) t;
