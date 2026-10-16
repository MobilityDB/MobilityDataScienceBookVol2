-- -----------------------------------------------------------------------------
-- Build the tables of the use case on the wind fields of the storms of a
-- season (Sect. "Temporal Geometries and Temporal Geographies" of Chapter 3)
-- from the tables loaded by storms_load.sh.
--
-- Usage: psql -d <database> -v year=<year> -f storms.sql
--
-- Input (one row per feature of the shapefiles of NOAA):
--   Points<year>  the observations of the tracks: StormName, DTG (the valid
--                 time, coded YYYYMMDDHH in UTC), Basin, StormNum, StormType,
--                 Intensity (knots), MSLP (millibars), SS (Saffir-Simpson
--                 category), Lat, Lon, Geom (Point, SRID 4326)
--   Radii<year>   the wind radii: Radii (34, 50 or 64 knots), StormId,
--                 SynopTime (coded YYYYMMDDHH in UTC), NE, SE, SW, NW (the
--                 radius of each quadrant in nautical miles), Geom
--                 (MultiPolygon, SRID 4326)
--   Swath<year>   the wind swaths: Radii, StormId, Geom (MultiPolygon)
--
-- Output:
--   StormPoints(StormId, Name, T, Geom)   one row per observation
--   StormRadii(StormId, Radii, T, Geom)   one row per wind radii polygon
--   StormSwath(StormId, Radii, Geom)      one row per wind swath
--   Storms<year>_tgeo(StormId, Name, Radii, Temp)
--                                         the wind field of a storm for a
--                                         wind speed, as a tgeography
--   Storms<year>_tpoint(StormId, Name, Temp, Traj)
--                                         the track of a storm, as a tgeompoint
--   Storms<year>_tcbuffer(StormId, Name, Radii, Temp, Trav)
--                                         the wind field as a tcbuffer and the
--                                         area it traverses
-- -----------------------------------------------------------------------------
\set ON_ERROR_STOP on
\set points Points :year
\set radii Radii :year
\set swath Swath :year
\set tgeo Storms :year _tgeo
\set tpoint Storms :year _tpoint
\set tcbuffer Storms :year _tcbuffer

-- The coded times are read in the time zone of the session, which is that of
-- the data
SET TimeZone = 'UTC';

-- -----------------------------------------------------------------------------
-- The observations and the wind radii, with timestamps
-- -----------------------------------------------------------------------------

-- A storm is identified by its basin, number and year, such as AL142024 for
-- Hurricane Milton, and named by the last name of its track: the name changes
-- over the life of a cyclone, for instance from GENESIS028 and INVEST to MILTON.
-- The archive also holds the potential tropical cyclones, systems for which NHC
-- issues advisories because they threaten land with tropical storm force winds
-- but which may never become tropical, such as AL082024 in 2024. A storm is
-- kept when at least one observation of its track is tropical or subtropical:
-- a tropical depression (TD), a tropical storm (TS), a hurricane (HU), a
-- subtropical depression (SD) or a subtropical storm (SS)
DROP TABLE IF EXISTS StormPoints;
CREATE TABLE StormPoints(StormId text, Name text, T timestamptz,
  Geom geometry(Point, 4326));
INSERT INTO StormPoints
SELECT upper(Basin) || lpad(StormNum::int::text, 2, '0') || :'year',
  last_value(initcap(StormName)) OVER (PARTITION BY Basin, StormNum ORDER BY DTG
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING),
  to_timestamp(DTG::bigint::text, 'YYYYMMDDHH24'), Geom
FROM :points p
WHERE EXISTS (
  SELECT 1 FROM :points q
  WHERE q.Basin = p.Basin AND q.StormNum = p.StormNum AND
    q.StormType IN ('TD', 'TS', 'HU', 'SD', 'SS') );

DROP TABLE IF EXISTS StormRadii;
CREATE TABLE StormRadii(StormId text, Radii integer, T timestamptz,
  Geom geometry(MultiPolygon, 4326));
INSERT INTO StormRadii
SELECT StormId, Radii, to_timestamp(SynopTime, 'YYYYMMDDHH24'), Geom
FROM :radii
WHERE StormId IN (SELECT StormId FROM StormPoints);

DROP TABLE IF EXISTS StormSwath;
CREATE TABLE StormSwath(StormId text, Radii integer,
  Geom geometry(MultiPolygon, 4326));
INSERT INTO StormSwath
SELECT StormId, Radii, Geom
FROM :swath
WHERE StormId IN (SELECT StormId FROM StormPoints);

-- Every wind radii polygon is observed at an instant of the track of its
-- storm, which the wind fields below rely on
SELECT count(*) AS radii_without_observation
FROM StormRadii r
WHERE NOT EXISTS (
  SELECT 1 FROM StormPoints p WHERE p.StormId = r.StormId AND p.T = r.T );

-- -----------------------------------------------------------------------------
-- The wind fields as temporal geographies
-- -----------------------------------------------------------------------------

-- The coordinates are longitudes and latitudes, so the wind fields are temporal
-- geographies, whose relationships, distances and areas are computed on the
-- WGS 84 ellipsoid

-- The wind field of a storm for a wind speed holds, at each observation of
-- the track, the area reached by this speed, and the position of the storm, a
-- region of no extent, at the observations at which the storm does not reach
-- it. A new sequence starts whenever two consecutive observations are more
-- than one day apart, and a wind speed the storm never reaches gives no row
DROP TABLE IF EXISTS :tgeo;
CREATE TABLE :tgeo(StormId text, Name text, Radii integer,
  Temp tgeography(SequenceSet, Geometry, 4326));
INSERT INTO :tgeo
WITH Thresholds(Radii) AS (VALUES (34), (50), (64))
SELECT p.StormId, p.Name, h.Radii,
  tgeographySeqSetGaps(array_agg(tgeography(coalesce(r.Geom, p.Geom)::geography,
    p.T) ORDER BY p.T), interval '1 day')
FROM StormPoints p CROSS JOIN Thresholds h
  LEFT JOIN StormRadii r ON r.StormId = p.StormId AND r.Radii = h.Radii AND
    r.T = p.T
GROUP BY p.StormId, p.Name, h.Radii
HAVING bool_or(r.Geom IS NOT NULL);

-- -----------------------------------------------------------------------------
-- The tracks as temporal points, on the same instants and with the same gaps
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS :tpoint;
CREATE TABLE :tpoint(StormId text, Name text,
  Temp tgeompoint(SequenceSet, Point, 4326), Traj geometry);
INSERT INTO :tpoint(StormId, Name, Temp)
SELECT StormId, Name,
  tgeompointSeqSetGaps(array_agg(tgeompoint(Geom, T) ORDER BY T), interval '1 day')
FROM StormPoints
GROUP BY StormId, Name;
UPDATE :tpoint SET Traj = trajectory(Temp);

-- -----------------------------------------------------------------------------
-- The wind fields as temporal circular buffers
-- -----------------------------------------------------------------------------

-- Each instant of a wind field is cast to a temporal circular buffer, which
-- replaces its multipolygon by the minimum bounding circle and its position by
-- a circle of radius 0. The instants are cast one by one from the observations
-- rather than from the stepwise temporal geometry, which drops an instant whose
-- value equals the previous one, an instant the linear interpolation needs
DROP TABLE IF EXISTS :tcbuffer;
CREATE TABLE :tcbuffer(StormId text, Name text, Radii integer,
  Temp tcbuffer(SequenceSet), Trav geometry);
INSERT INTO :tcbuffer(StormId, Name, Radii, Temp)
WITH Thresholds(Radii) AS (VALUES (34), (50), (64))
SELECT p.StormId, p.Name, h.Radii,
  tcbufferSeqSetGaps(array_agg(tcbuffer(tgeometry(coalesce(r.Geom, p.Geom), p.T))
    ORDER BY p.T), interval '1 day')
FROM StormPoints p CROSS JOIN Thresholds h
  LEFT JOIN StormRadii r ON r.StormId = p.StormId AND r.Radii = h.Radii AND
    r.T = p.T
GROUP BY p.StormId, p.Name, h.Radii
HAVING bool_or(r.Geom IS NOT NULL);
UPDATE :tcbuffer SET Trav = traversedArea(Temp);

-- -----------------------------------------------------------------------------
-- Summary
-- -----------------------------------------------------------------------------

SELECT (SELECT count(*) FROM StormPoints) AS observations,
  (SELECT count(*) FROM StormRadii) AS radii,
  (SELECT count(DISTINCT StormId) FROM :tgeo) AS storms,
  (SELECT count(*) FROM :tgeo) AS wind_fields,
  (SELECT sum(numInstants(Temp)) FROM :tgeo) AS instants;
