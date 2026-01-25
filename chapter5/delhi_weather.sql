
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

-- OLD VERSION that does not take into account hour boundaries

DROP TABLE IF EXISTS TripsWeather;
CREATE TABLE TripsWeather(TripId integer, Weather tjsonb, PRIMARY KEY(TripId));
INSERT INTO TripsWeather
WITH TripSegments(TripId, Segm) AS (
  SELECT TripId, unnest(segments(Trip))
  FROM DelhiTrips )
SELECT TripId, tjsonbSeq(array_agg(tjsonb(w.Weather, startTimestamp(Segm))
    ORDER BY startTimestamp(Segm)))
  FROM TripSegments t, WeatherHourly w
  WHERE date_trunc('hour', startTimestamp(t.Segm)) = w.Time
GROUP BY TripId
ORDER BY TripId;

-- INSERT 0 27118
-- Time: 28001.169 ms (00:28.001)

/*****************************************************************************/

-- NEW VERSION !!!

DROP TABLE IF EXISTS TripsWeather;
CREATE TABLE TripsWeather(TripId integer, Weather tjsonb, PRIMARY KEY(TripId));
INSERT INTO TripsWeather
WITH TripInstants(TripId, Inst) AS (
  SELECT TripId, unnest(instants(Trip))
  FROM DelhiTrips ),
TempWeather(Weather) AS (
  SELECT tjsonbSeq(array_agg(tjsonb(Weather, Time) ORDER BY Time))
  FROM WeatherHourly ),
WeatherAtTrip(TripId, Weather) AS (
  SELECT TripId, atTime(w.Weather, getTime(Trip))
  FROM DelhiTrips t, TempWeather w ),
WeatherInstants(TripId, Instants) AS (
  SELECT TripId, tjsonbseq(array_agg(tjsonb(w.Weather, getTimestamp(Inst))
    ORDER BY getTimestamp(Inst)), 'Discrete' )
  FROM TripInstants t, WeatherHourly w
  WHERE date_trunc('hour', getTimestamp(Inst)) = w.Time
  GROUP BY TripId)
SELECT t.TripId, update(t.Weather, i.Instants)
FROM WeatherAtTrip t, WeatherInstants i
WHERE t.TripId = i.TripId
ORDER BY TripId;

-- INSERT 0 27118
-- Time: 98817.356 ms (01:38.817)

/*****************************************************************************/
