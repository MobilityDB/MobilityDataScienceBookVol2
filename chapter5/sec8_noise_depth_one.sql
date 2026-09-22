-- Section 8: underwater noise radius depending on the depth of the water, for
-- the fishing vessel of Chap. 3 (MMSI 219013538, trip 1, January 1, 2025), on
-- the database loaded by the MobilityDB-Tcbuffer loader with Bathymetry added.
-- SL is the source level (dB), NL = 80 dB the ambient noise of every sea cell.
-- Spherical spreading: r = 10^((SL - NL)/20), valid up to r = 10 H.
-- Beyond 10 H (mode stripping, 15 log r + 5 log(10 H)):
--   r = 10^((SL - NL - 5 log10(10 H))/15).
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS NoiseDepthOne;
CREATE TABLE NoiseDepthOne AS
WITH Trip AS (
  SELECT MMSI, TripId, Trip, SL, Radius, Noise
  FROM VesselTrip WHERE MMSI = 219013538 AND TripId = 1 ),
Depth AS (
  SELECT t.MMSI, t.TripId, mergeAgg(rasterValue(t.Trip, b.Rast)) AS Depth
  FROM Trip t, Bathymetry b
  WHERE ST_Intersects(b.Rast, trajectory(t.Trip))
  GROUP BY t.MMSI, t.TripId )
SELECT t.MMSI, t.TripId, t.Trip, t.SL, t.Radius, t.Noise, d.Depth,
  ((t.SL - 80) #> 20 * log10(10 * d.Depth)) & (d.Depth #>= 10) AS Stripping
FROM Trip t JOIN Depth d USING (MMSI, TripId);

SELECT interp(SL) AS InterpSL, interp(Depth) AS InterpDepth,
  round(minValue(Depth)::numeric, 1) AS MinDepth, round(maxValue(Depth)::numeric, 1) AS MaxDepth,
  duration(getTime(Depth)) AS DepthTime, duration(getTime(Trip)) AS TripTime,
  duration(whenTrue(Stripping)) AS StrippingTime,
  round(minValue(SL)::numeric, 1) AS MinSL, round(maxValue(SL)::numeric, 1) AS MaxSL
FROM NoiseDepthOne;
