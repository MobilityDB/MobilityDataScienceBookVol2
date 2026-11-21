-- SPDX-License-Identifier: PostgreSQL
-------------------------------------------------------------------------------
-- Mobility Data Science: From Edge to Cloud Processing
-- Chapter 10: Mobility Data Pipelines
--
-- The answers of Exercise 3 that are queries, as printed in the chapter; Exercises 1 and 2
-- are answered by reasoning on the bounds and the cells and run no query. The exercise reads
-- the view Belt, which is the view Strait of Sect. "Querying the Lakehouse": both restrict the
-- trajectories to the Fehmarn Belt during the window. bind.py replaces the parameters by the
-- values of a window and prefixes the view trips over a layout, as for queries.sql.
-------------------------------------------------------------------------------

-- @region belt
CREATE OR REPLACE VIEW Strait AS
SELECT MMSI, ship_type, Trip FROM (
  SELECT MMSI, ship_type, atStbox(tgeompointFromEWKB(trip), stbox(
    'SRID=25832;STBOX XT(((:rxmin,:rymin),(:rxmax,:rymax)),[:t0,:t1])')) AS Trip
  FROM trips
  WHERE dt BETWEEN :d0 AND :d1 AND
    trip_tmax >= :t0 AND trip_tmin <= :t1 AND
    trip_xmax >= :rxmin AND trip_xmin <= :rxmax AND
    trip_ymax >= :rymin AND trip_ymin <= :rymax ) AS t
WHERE Trip IS NOT NULL;
CREATE OR REPLACE VIEW Belt AS SELECT * FROM Strait;

-- @region belt
-- Exercise 3.1: For each ship type, how many vessels were in the belt during the window, and
-- how long did they stay there in total?
SELECT ship_type, COUNT(DISTINCT MMSI) AS NoVessels,
  SUM(duration(Trip)) AS TotalTime
FROM Belt
GROUP BY ship_type
ORDER BY NoVessels DESC;

-- @region belt
-- Exercise 3.2: How many stops longer than one hour began in the belt during the window?
SELECT COUNT(*) AS NoStops
FROM trips
WHERE segment_type = 'Stationary' AND
  trip_tmax - trip_tmin > INTERVAL '1 hour' AND
  dt BETWEEN :d0 AND :d1 AND trip_tmin BETWEEN :t0 AND :t1 AND
  trip_xmax >= :rxmin AND trip_xmin <= :rxmax AND
  trip_ymax >= :rymin AND trip_ymin <= :rymax AND
  ST_Intersects(startValue(tgeompointFromEWKB(trip)),
    ST_MakeEnvelope(:rxmin, :rymin, :rxmax, :rymax));
