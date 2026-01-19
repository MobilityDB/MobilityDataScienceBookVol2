
SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';

WITH Extent(MinLon, MinLat, MaxLon, MaxLat) AS (
  SELECT MIN(Lon), MIN(Lat), MAX(Lon), MAX(Lat)
  FROM DelhiInput )
SELECT MinLon + (MaxLon - MinLon) / 2 AS CenterLon,
  MinLat + (MaxLat - MinLat) / 2 AS CenterLat
FROM Extent;

-- 77.21044149999999 | 28.603272625000002
-- Time: 3490.939 ms (00:03.491)

-- OpenMeteo does not support IndiaStandardTime so we do not set the timezone
-- and thus the timezone will be GMT. Therefore, we need to set the timezone
-- to Asia/Koklata BEFORE loading the CSV file
-- We suppose that the CSV file is called delhi_weather.csv
/*
https://open-meteo.com/en/docs/historical-weather-api?start_date=2020-11-01&end_date=2020-12-31&latitude=28.603272&longitude=77.210441&hourly=temperature_2m,relative_humidity_2m,cloud_cover,rain,wind_speed_10m
*/

DROP TABLE IF EXISTS WeatherInput;
CREATE TABLE WeatherInput(Time timestamptz PRIMARY KEY, Temperature float,
  Humidity float, CloudCover float, Rain float, Wind float);
COPY WeatherInput (Time, Temperature, Humidity, CloudCover, Rain, Wind)
FROM '/home/esteban/data/delhi/delhi_weather.csv'
DELIMITER ',' CSV HEADER;

-- COPY 360
-- Time: 7.408 ms

DROP TABLE IF EXISTS WeatherHourly;
CREATE TABLE WeatherHourly(Time timestamptz PRIMARY KEY,
  TimeSpan tstzspan UNIQUE, Weather jsonb);
INSERT INTO WeatherHourly(Time, TimeSpan, Weather)
SELECT Time, span(Time, Time + interval '1 hour'), jsonb_build_object(
  'Temperature', Temperature,  'Humidity', Humidity, 'CloudCover',
  CloudCover, 'Rain', Rain, 'Wind', Wind)
FROM WeatherInput;

-- INSERT 0 360
-- Time: 32.467 ms

CREATE INDEX WeatherHourly_QuadTree_Idx ON WeatherHourly USING SPGIST(TimeSpan);

-- Time: 16.874 ms

DROP TABLE IF EXISTS DelhiInputSem;
CREATE TABLE DelhiInputSem(DeviceId text, T timestamptz, Attributes jsonb,
  PRIMARY KEY(DeviceId, T));
INSERT INTO DelhiInputSem(DeviceId, T, Attributes)
SELECT DeviceId, T, w.Weather || jsonb_build_object('Pm25', d.Pm2_5)
FROM DelhiInput d, WeatherHourly w
WHERE date_trunc('hour', d.T) = w.Time;

-- INSERT 0 7087619
-- Time: 124838.994 ms (02:04.839)