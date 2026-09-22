-- Section 8: radius of the noise of the example trip with spreading depending
-- on the depth, as a temporal float, and the resulting temporal circular buffer,
-- compared with the spherical radius of Chap. 3. The exponent of the radius is
-- (SL - 80)/20 where spreading is spherical and (SL - 80 - 5 log10(10 H))/15
-- where it is not; it is capped at 4, that is, at 10 km.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS NoiseDepthOneR;
CREATE TABLE NoiseDepthOneR AS
WITH Exponent AS (
  SELECT MMSI, TripId, Trip, Radius, Noise, Depth,
    merge(
      atTime((SL - 80) / 20, getTime(Trip) - whenTrue(Stripping)),
      atTime((SL - 80 - 5 * log10(10 * Depth)) / 15, whenTrue(Stripping))) AS E
  FROM NoiseDepthOne ),
Capped AS (
  SELECT *, merge(atSpan(E, floatspan '[-10, 4)'), tfloat(4.0, whenTrue(E #>= 4))) AS EC
  FROM Exponent )
SELECT MMSI, TripId, Trip, Radius, Noise, Depth,
  exp(EC * ln(10)) AS RadiusDepth, tcbuffer(Trip, exp(EC * ln(10))) AS NoiseDepth
FROM Capped;

SELECT round(maxValue(Radius)::numeric) AS MaxRadius,
  round(maxValue(RadiusDepth)::numeric) AS MaxRadiusDepth,
  duration(whenTrue(RadiusDepth #>= 9999.999)) AS CappedTime,
  round((ST_Area(traversedArea(Noise, true)) / 1e6)::numeric, 1) AS AreaKm2,
  round((ST_Area(traversedArea(NoiseDepth, true)) / 1e6)::numeric, 1) AS AreaDepthKm2
FROM NoiseDepthOneR;

SELECT n.Id, n.NameEng,
  duration(whenTrue(tIntersects(r.Noise, n.Geom))) AS Spherical,
  duration(whenTrue(tIntersects(r.NoiseDepth, n.Geom))) AS DepthAware
FROM NoiseDepthOneR r, NaturalAreas n
WHERE eIntersects(n.Geom, r.NoiseDepth)
ORDER BY 4 DESC;
