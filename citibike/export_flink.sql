-- The files that the chapter on stream processing reads, exported from the Citi Bike tables
-- built by citibike_build.sql, as tab-separated values without a header line:
--   flink/trips: the trips that start on the day ${day}, in the order of their start, which the
--     producers replay into Kafka as a stream of events;
--   flink/stations: one line per station, with its borough and its Neighborhood Tabulation Area,
--     which the Flink jobs join with the stream.
-- Each directory holds a single part file, written by one partition sorted with SORT BY.

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/flink/trips'
USING csv OPTIONS (sep '\t', header 'false', timestampFormat 'yyyy-MM-dd HH:mm:ss')
SELECT /*+ REPARTITION(1) */
  ride_id, rideable_type, started_at, ended_at, start_station_id, start_station_name,
  end_station_id, end_station_name, start_lat, start_lng, end_lat, end_lng, member_casual
FROM trips
WHERE CAST(started_at AS DATE) = DATE '${day}'
SORT BY started_at, ride_id;

INSERT OVERWRITE DIRECTORY 'file://${data}/citibike/flink/stations'
USING csv OPTIONS (sep '\t', header 'false')
SELECT /*+ REPARTITION(1) */
  id, name, longitude, latitude, boroname, ntacode, ntaname, ST_AsText(geometry) AS geometry
FROM stations
SORT BY id;

SELECT 'trips of ${day}' AS file, COUNT(*) AS n FROM trips
WHERE CAST(started_at AS DATE) = DATE '${day}'
UNION ALL SELECT 'stations', COUNT(*) FROM stations;
