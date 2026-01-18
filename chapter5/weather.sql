
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

SET TIMEZONE TO 'Asia/Kolkata';

DROP TABLE IF EXISTS WeatherInput;
CREATE TABLE WeatherInput(Lon float, Lat float, Time timestamptz PRIMARY KEY,
  Temperature float, Humidity float, CloudCover float, Rain float, Wind float);
COPY WeatherInput (Time, Temperature, Humidity, CloudCover, Rain, Wind) 
-- FROM '/Users/avaisman/tmp/DataMisc/Delhi/delhi_weather.csv' DELIMITER ',' CSV HEADER;
FROM '/home/esteban/data/delhi/delhi_weather.csv' DELIMITER ',' CSV HEADER;

-- COPY 1464
-- Time: 16.902 ms

DROP TABLE IF EXISTS WeatherHourly;
CREATE TABLE WeatherHourly(Time timestamptz PRIMARY KEY,
  TimeSpan tstzspan UNIQUE, Weather jsonb);
INSERT INTO WeatherHourly(Time, TimeSpan, Weather)
SELECT Time, span(Time, Time + interval '1 hour'), jsonb_build_object(
  'Temperature', Temperature,  'Humidity', Humidity, 'CloudCover',
  CloudCover, 'Rain', Rain, 'Wind', Wind)
FROM WeatherInput;

-- INSERT 0 1464
-- Time: 44.024 ms

CREATE INDEX WeatherHourly_QuadTree_Idx ON WeatherHourly USING SPGIST(TimeSpan);

-- Time: 16.874 ms

ALTER TABLE DelhiInput ADD COLUMN IF NOT EXISTS Attributes jsonb;
UPDATE DelhiInput d
SET Attributes = w.Weather || jsonb_build_object('Pm25', d.Pm2_5)
FROM WeatherHourly w
WHERE date_trunc('hour', d.T) = w.Time;

-- UPDATE 7087619
-- Time: 551950.620 ms (09:11.951)