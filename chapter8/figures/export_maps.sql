-- The data of the four Citi Bike maps of the chapter, one CSV directory each below ${data}/citibike/maps,
-- from the tables built by citibike/citibike_build.sql, which citibike_maps.py draws:
--   stations: every station; start_trips: the trips per starting station; afternoon_dest: the
--   afternoon trips from Manhattan per destination station in another borough; columbus: the night
--   ratio of the stations within 500 m of Columbus Circle; columbus_buffer: that circle.
-- Run as citibike/build.sh runs export_flink.sql:  sql chapter8/figures/export_maps.sql

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/maps/stations'
USING csv OPTIONS (header 'true')
SELECT id, name, ST_X(geometry) AS lon, ST_Y(geometry) AS lat FROM stations;

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/maps/start_trips'
USING csv OPTIONS (header 'true')
SELECT s.name AS station_name, ST_X(s.geometry) AS lon, ST_Y(s.geometry) AS lat, COUNT(*) AS no_trips
FROM trips t, stations s
WHERE t.start_station_id = s.id
GROUP BY s.name, s.geometry;

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/maps/afternoon_dest'
USING csv OPTIONS (header 'true')
SELECT s2.name AS station_name, ST_X(s2.geometry) AS lon, ST_Y(s2.geometry) AS lat, COUNT(*) AS no_trips
FROM trips t, stations s1, stations s2
WHERE t.start_station_id = s1.id AND s1.boroname = 'Manhattan' AND
  t.end_station_id = s2.id AND s2.boroname != 'Manhattan' AND
  EXTRACT(HOUR FROM t.ended_at) BETWEEN 16 AND 20
GROUP BY s2.name, s2.geometry;

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/maps/columbus'
USING csv OPTIONS (header 'true')
WITH Columbus(geometry) AS (
  SELECT ST_Buffer(ST_SetSRID(ST_Point(-73.981676, 40.767984), 4326), 500, true) ),
EndStationsNight(end_station_name, end_station, end_geometry, no_end_trips) AS (
  SELECT t.end_station_name, t.end_station_id, s.geometry, COUNT(*)
  FROM Columbus c, trips t, stations s
  WHERE t.end_station_id = s.id AND ST_Contains(c.geometry, s.geometry) AND
    (EXTRACT(HOUR FROM t.started_at) BETWEEN 18 and 23 OR
     EXTRACT(HOUR FROM t.started_at) BETWEEN 0 and 5)
  GROUP BY t.end_station_name, t.end_station_id, s.geometry),
StartStationsNight(start_station, start_geometry, no_start_trips) AS (
  SELECT t.start_station_id, s.geometry, COUNT(*)
  FROM Columbus c, trips t, stations s
  WHERE t.start_station_id = s.id AND ST_Contains(c.geometry, s.geometry) AND
    (EXTRACT(HOUR FROM t.started_at) BETWEEN 18 and 23 OR
     EXTRACT(HOUR FROM t.started_at) BETWEEN 0 and 5)
  GROUP BY t.start_station_id, s.geometry )
SELECT e.end_station_name AS station, ST_X(e.end_geometry) AS lon, ST_Y(e.end_geometry) AS lat,
  s.no_start_trips, e.no_end_trips,
  round(e.no_end_trips / CAST(s.no_start_trips AS DECIMAL(20,4)), 2) AS ratio
FROM EndStationsNight e, StartStationsNight s
WHERE e.end_station = s.start_station;

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/maps/columbus_buffer'
USING csv OPTIONS (header 'true')
SELECT ST_AsText(ST_Buffer(ST_SetSRID(ST_Point(-73.981676, 40.767984), 4326), 500, true)) AS wkt;
