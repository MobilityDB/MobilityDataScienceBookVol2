
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

-- COPY 360
-- Time: 7.408 ms

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

DROP TABLE IF EXISTS Grid;
CREATE TABLE Grid(CellId integer PRIMARY KEY, Box stbox, Geom geometry);
INSERT INTO Grid(CellId, Box, Geom)
WITH MBR(Box) AS ( SELECT extent(Geom::stbox) FROM DelhiInput )
SELECT (rec).Index, (rec).Tile, (rec).Tile::geometry
FROM ( SELECT spaceTiles(Box, 2500) AS rec FROM MBR );

-- 120 rows
-- Time: 2958.447 ms (00:02.958)

CREATE INDEX Grid_Box_Quadtree_Idx ON Grid USING SPGIST(Box);
CREATE INDEX Grid_Geom_Quadtree_Idx ON Grid USING SPGIST(Geom);

--

DROP TABLE IF EXISTS TripCells;
CREATE TABLE TripCells(TripId integer, CellId integer, StartTime timestamptz,
  EndTime timestamptz, Pm25Min float, Pm25Max float, Pm25Avg float, Weather jsonb,
  PRIMARY KEY (TripId, CellId, StartTime));
INSERT INTO TripCells
WITH TripPointCells(TripId, CellId, T, Pm25, Geom, Weather) AS (
  SELECT p.TripId, g.CellId, p.T, p.Pm25, p.Geom, p.Weather
  FROM TripPoints p, Grid g
  WHERE g.Box @> stbox(p.Geom) ),
TripPointCellsLagged(TripId, CellId, T, Pm25, Geom, Weather, PrevCell) AS (
  SELECT *, LAG(CellId) OVER (PARTITION BY TripId ORDER BY T ) AS PrevCell
  FROM TripPointCells ),
TripCellGrouped(TripId, CellId, T, Pm25, Geom, Weather, PrevCell, NewGroup) AS (
  SELECT *, 
    CASE WHEN PrevCell IS NULL OR CellId <> PrevCell THEN 1 ELSE 0 END
  FROM TripPointCellsLagged ),
TripGroups(TripId, CellId, T, Pm25, Geom, Weather, PrevCell, NewGroup, GroupId) AS (
  SELECT *, SUM(NewGroup) OVER (PARTITION BY TripId ORDER BY T
    ROWS UNBOUNDED PRECEDING)
  FROM TripCellGrouped )
SELECT TripId, CellId, MIN(T), MAX(T), MIN(Pm25), MAX(Pm25), AVG(Pm25),
  jsonb_build_object(
    'Temperature', AVG((Weather->>'Temperature')::float),
    'Humidity', AVG((Weather->>'Humidity')::float),
    'CloudCover', AVG((Weather->>'CloudCover')::float),
    'Rain', AVG((Weather->>'Rain')::float),
    'Wind', AVG((Weather->>'Wind')::float)) AS Weather
FROM TripGroups
GROUP BY TripId, CellId, GroupId
ORDER BY TripId, CellId;

-- 70881 rows
-- Time: 116866.677 ms (01:56.867)

-- NEW VERSION

DROP TABLE IF EXISTS TripCells;
CREATE TABLE TripCells(TripId integer, CellId integer, StartTime timestamptz,
  EndTime timestamptz, Pm25Min float, Pm25Max float, Pm25 float, Weather jsonb,
  PRIMARY KEY (TripId, CellId, StartTime));
INSERT INTO TripCells
WITH TripPointCells(TripId, CellId, T, Pm25, Geom, Weather, PrevCell) AS (
  SELECT p.TripId, g.CellId, p.T, p.Pm25, p.Geom, p.Weather,
    LAG(CellId) OVER (PARTITION BY TripId ORDER BY T )
  FROM TripPoints p, Grid g
  WHERE g.Box @> stbox(p.Geom) ),
TripCellGrouped(TripId, CellId, T, Pm25, Geom, Weather, PrevCell, NewGroup) AS (
  SELECT *, 
    CASE WHEN PrevCell IS NULL OR CellId <> PrevCell THEN 1 ELSE 0 END
  FROM TripPointCells ),
TripGroups(TripId, GroupId, CellId, T, Pm25, Geom, Weather, PrevCell) AS (
  SELECT TripId, SUM(NewGroup) OVER (PARTITION BY TripId ORDER BY T
    ROWS UNBOUNDED PRECEDING), CellId, T, Pm25, Geom, Weather, PrevCell
  FROM TripCellGrouped )
SELECT TripId, CellId, MIN(T), MAX(T), MIN(Pm25), MAX(Pm25), AVG(Pm25),
  jsonb_build_object(
    'Temperature', AVG((Weather->>'Temperature')::float),
    'Humidity', AVG((Weather->>'Humidity')::float),
    'CloudCover', AVG((Weather->>'CloudCover')::float),
    'Rain', AVG((Weather->>'Rain')::float),
    'Wind', AVG((Weather->>'Wind')::float)) AS Weather
FROM TripGroups
GROUP BY TripId, CellId, GroupId
ORDER BY TripId, CellId;



DROP TABLE TripsTiled;
CREATE TABLE TripsTiled(TripId integer, CellId integer, TimeCell tstzspan,
  TripCell tgeompoint, Traj geometry, Speed tfloat, Weather tjsonb, 
  PRIMARY KEY (TripId, CellId, TimeCell) );
INSERT INTO TripsTiled
WITH TripCells(TripId, CellId, TimeCell, TripCell, Weather) AS (
  SELECT TripId, CellId, unnest(spans(getTime(atStbox(t.Trip, g.Box)))),
    atStbox(t.Trip, g.Box), Weather
  FROM Trips t, Grid g
  WHERE eIntersects(t.Trip, g.Geom) )
SELECT TripId, CellId, TimeCell, TripCell, trajectory(TripCell), speed(TripCell),
  atTime(Weather, TimeCell)
FROM TripCells
ORDER BY TripId, CellId;

-- 71278 rows
-- Time: 155921.229 ms (02:35.921)

/*****************************************************************************/
