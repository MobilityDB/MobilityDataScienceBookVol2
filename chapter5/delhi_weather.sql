
SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';

/* Compute the center point of the extent of the dataset 

WITH Extent(MinLon, MinLat, MaxLon, MaxLat) AS (
  SELECT MIN(Lon), MIN(Lat), MAX(Lon), MAX(Lat)
  FROM DelhiInput )
SELECT MinLon + (MaxLon - MinLon) / 2 AS CenterLon,
  MinLat + (MaxLat - MinLat) / 2 AS CenterLat
FROM Extent;

-- 77.21044149999999 | 28.603272625000002
-- Time: 3490.939 ms (00:03.491)

-- OpenMeteo should be set to automatically detect the timezone from the data,
-- which in this case it would be Indian Standard Time or IST . Therefore, 
-- we need to set the timezone to Asia/Koklata in PostgreSQL BEFORE loading
-- the CSV file. We suppose that the CSV file is called delhi_weather.csv

https://open-meteo.com/en/docs/historical-weather-api?start_date=2020-11-01&end_date=2020-12-31&latitude=28.603272&longitude=77.210441&hourly=temperature_2m,relative_humidity_2m,cloud_cover,rain,wind_speed_10m

*/

DROP TABLE IF EXISTS WeatherInput;
CREATE TABLE WeatherInput(T timestamptz PRIMARY KEY, Temperature float,
  Humidity float, CloudCover float, Rain float, Wind float);
COPY WeatherInput (T, Temperature, Humidity, CloudCover, Rain, Wind)
FROM '/home/esteban/data/delhi/delhi_weather.csv' DELIMITER ',' CSV HEADER;

-- COPY 1464
-- Time: 14.176 ms

DROP TABLE IF EXISTS WeatherHourly;
CREATE TABLE WeatherHourly(T timestamptz PRIMARY KEY,
  TimeSpan tstzspan UNIQUE, Weather jsonb);
INSERT INTO WeatherHourly(T, TimeSpan, Weather)
SELECT T, span(T, T + interval '1 hour'), jsonb_build_object(
  'Temperature', Temperature,  'Humidity', Humidity, 'CloudCover', CloudCover,
  'Rain', Rain, 'Wind', Wind)
FROM WeatherInput;

-- 1464 rows
-- Time: 36.679 ms

CREATE INDEX WeatherHourly_QuadTree_Idx ON WeatherHourly USING SPGIST(TimeSpan);

-- Time: 16.874 ms

DROP TABLE IF EXISTS TripPoints;
CREATE TABLE TripPoints(TripId integer, T timestamptz, Pm25 float,
  Geom geometry, Weather jsonb, PRIMARY KEY(TripId, T));
INSERT INTO TripPoints
WITH TripStarts(DeviceId, T, Pm2_5, Geom, NewTrip) AS (
  SELECT DeviceId, T, Pm2_5, Geom,
    CASE 
      WHEN LAG(T) OVER w IS NULL OR T - LAG(T) OVER w > '5 minutes' OR
        ST_Distance(Geom, LAG(Geom) OVER w) > 1000 THEN 1
    END
  FROM DelhiInput
  WINDOW w AS (PARTITION BY DeviceId ORDER BY T) ),
TripGroup(TripId, T, Pm2_5, Geom) AS (
  SELECT COUNT(NewTrip) OVER (ORDER BY DeviceId, T), T, Pm2_5, Geom 
  FROM TripStarts )
SELECT g.TripId, g.T, g.Pm2_5, g.Geom, w.Weather
FROM TripGroup g, WeatherHourly w
WHERE date_trunc('hour', g.T) = w.T
ORDER BY TripId;

-- 7087619 rows, 27118 trips
-- Time: 96047.702 ms (01:36.048)

DROP TABLE IF EXISTS Trips;
CREATE TABLE Trips(TripId integer PRIMARY KEY, Trip tgeompoint,
  Trajectory geometry, Pm25 tfloat, Weather tjsonb);
INSERT INTO Trips
WITH Trips(TripId, Trip, Pm25, Weather) AS (
  SELECT TripId, 
    tgeompointSeq(array_agg(tgeompoint(Geom, T) ORDER BY T)),
    tfloatSeq(array_agg(tfloat(Pm25, T) ORDER BY T)),
    tjsonbSeq(array_agg(tjsonb(Weather, T) ORDER BY T))
  FROM TripPoints
  GROUP BY TripId )
SELECT TripId, Trip, trajectory(Trip), Pm25, Weather
FROM Trips
ORDER BY TripId;

--  27118 rows
-- Time: 53780.456 ms (00:53.780)

CREATE INDEX Trips_Trip_Quadtree_Idx ON Trips USING SPGIST(Trip);

-- Time: 53780.456 ms (00:53.780)

/*****************************************************************************/
