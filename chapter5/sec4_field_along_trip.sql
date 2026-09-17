-- Section 4: reading a field along a trajectory, on a synthetic 4x4 raster
-- of 100 m pixels in EPSG:25832 whose values are depths in metres.
\pset footer off
DROP TABLE IF EXISTS Depth, Salinity;
CREATE TABLE Depth(Rast raster);
INSERT INTO Depth
SELECT ST_SetValues(
  ST_AddBand(ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
    '32BF'::text, 0, -9999),
  1, 1, 1, ARRAY[[12,14,16,18],[11,13,15,17],[9,10,12,14],[6,8,9,11]]
    ::double precision[][]);

\echo == ST_Value at one position
SELECT ST_Value(Rast, 1, ST_Point(600150, 6400250, 25832)) FROM Depth;

\echo == rasterValue along a trip crossing a row of pixels
SELECT asText(rasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast))
FROM Depth;

\echo == rasterValue along a diagonal trip through pixel corners
SELECT asText(rasterValue(tgeompoint '[SRID=25832;Point(600050 6400350)@2025-01-01 08:00,
  SRID=25832;Point(600350 6400050)@2025-01-01 08:06]', Rast))
FROM Depth;

\echo == atRasterValue: the part of the trip over water less than 11 m deep
SELECT asText(atRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)'))
FROM Depth;

\echo == eRasterValue and aRasterValue
SELECT eRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)') AS ever,
  aRasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, floatspan '[0, 11)') AS always
FROM Depth;

\echo == bilinear along a moving trip
SELECT asText(rasterValue(tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:00,
  SRID=25832;Point(600380 6400150)@2025-01-01 08:06]', Rast, 1, true, 'bilinear'))
FROM Depth;

\echo == bilinear at an instant on a pixel corner
SELECT asText(rasterValue(tgeompoint 'SRID=25832;Point(600100 6400300)@2025-01-01 08:00',
  Rast, 1, true, 'bilinear'))
FROM Depth;

-- A field that changes over time: two hourly steps of a salinity field.
CREATE TABLE Salinity(ValidTime tstzspan, Rast raster);
INSERT INTO Salinity
SELECT tstzspan '[2025-01-01 08:00, 2025-01-01 09:00)', ST_SetValues(
  ST_AddBand(ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
    '32BF'::text, 0, -9999),
  1, 1, 1, ARRAY[[20,21,22,23],[20,21,22,23],[20,21,22,23],[20,21,22,23]]::double precision[][])
UNION ALL
SELECT tstzspan '[2025-01-01 09:00, 2025-01-01 10:00)', ST_SetValues(
  ST_AddBand(ST_MakeEmptyRaster(4, 4, 600000, 6400400, 100, -100, 0, 0, 25832),
    '32BF'::text, 0, -9999),
  1, 1, 1, ARRAY[[24,25,26,27],[24,25,26,27],[24,25,26,27],[24,25,26,27]]::double precision[][]);

\echo == a field held constant during each time step
WITH Trip AS (
  SELECT tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:40,
    SRID=25832;Point(600380 6400150)@2025-01-01 09:16]' AS Trip)
SELECT asText(mergeAgg(rasterValue(atTime(t.Trip, s.ValidTime), s.Rast)
  ORDER BY s.ValidTime))
FROM Trip t, Salinity s
WHERE t.Trip && s.ValidTime;

\echo == nearest in space and linear in time between the steps at 08:00 and 09:00
WITH Trip AS (
  SELECT tgeompoint '[SRID=25832;Point(600020 6400150)@2025-01-01 08:10,
    SRID=25832;Point(600380 6400150)@2025-01-01 08:46]' AS Trip),
Steps AS (
  SELECT
    (SELECT Rast FROM Salinity WHERE lower(ValidTime) = '2025-01-01 08:00') AS R1,
    (SELECT Rast FROM Salinity WHERE lower(ValidTime) = '2025-01-01 09:00') AS R2)
SELECT asText(rasterValue(Trip, R1) +
  (rasterValue(Trip, R2) - rasterValue(Trip, R1)) *
  atTime(tfloat '[0@2025-01-01 08:00, 1@2025-01-01 09:00]', getTime(Trip)))
FROM Trip, Steps;
