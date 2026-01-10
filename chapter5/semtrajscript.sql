CREATE TABLE Grid(CellId, Box) AS
WITH MBR(Box) AS (
  SELECT ST_Extent(Geom)
  FROM DelhiInput)
SELECT (rec).Index, (rec).Tile
FROM ( SELECT spaceTiles(Box, 2500) AS rec FROM MBR );

CREATE TABLE PM25Hourly(CellId, DatePol, PM25) AS
SELECT g.CellId, date_trunc('hour', d.t), AVG(PM2_5)
FROM Grid g, DelhiInput d
WHERE ST_Contains(g.Box::geometry, d.Geom::geometry)
GROUP BY g.CellId, date_trunc('hour', d.t)
ORDER BY g.CellId, date_trunc('hour', d.t);
 
CREATE TABLE WeatherHourly(Time timestamp, Temperature float, Rain float,
  Wind float, Humidity float);
COPY WeatherHourly (Time, Temperature, Rain, Wind, Humidity)
  FROM '/.../delhiRainTempHumid.csv' DELIMITER ';' CSV HEADER ;
  
CREATE TABLE SemTrajJSON AS(
WITH TimeCells(TripId, CellId, TimeCell, TripCell)  AS( 
  SELECT TripId, CellId, 
       unnest(spans(getTime(atStbox(d.Trip, g.Box)))),
       atStbox(d.Trip, g.Box)
  FROM DelhiTrips d, Grid g
  WHERE atStbox(d.Trip, g.Box) IS NOT NULL 
 	AND eIntersects(d.Trip, g.Box)  
  ORDER BY TripId, TimeCell),

GeoCells (TripId, CellId, TimeCell, TripCell, TripCellTraj, StartTime, EndTime) AS(
  SELECT t.TripId, t.CellId, TimeCell, atTime(d.Trip, TimeCell),
       trajectory(atTime(d.Trip, TimeCell)),
       getTimestamp(startInstant(atTime(d.Trip, TimeCell))),
       getTimestamp(endInstant(atTime(d.Trip, TimeCell)))
  FROM DelhiTrips d, TimeCells t 
  WHERE eIntersects(d.Trip, t.TripCell)
  ORDER BY T.TripId ),    
Weather (TripId, CellId, TimeCell, TripCell, TripCellTraj,
	    Temperature, Time,  Rain, Wind, Humidity,
	    StartTime, EndTime AS (
	SELECT t.TripId,  t.CellId, t.TimeCell, t.TripCell, t.TripCellTraj,
 	w.Temperature, w.Time, w.Rain,  w.Wind, 
	w.Humidity, t.StartTime, t.EndTime
	FROM GeoCells t, WeatherHourly w
        WHERE w.Time = date_trunc('hour', t.StartTime + (t.EndTime - t.StartTime) / 2) ),
WeatherPM AS (
  SELECT w.*, ROUND(p.pm25::numeric, 2) AS Pm25
  FROM Weather w, PM25Hourly p
  WHERE a.CellId = p.CellId AND
    p.DatePol = date_trunc('hour', StartTime + (EndTime - StartTime) / 2)  
  ORDER BY TripId, StartTime)
SELECT
    TripId, TripCell, TripCellTraj, CellId, TimeCell,
    jsonb_build_object(
        'cellId', CellId,
	'cellInterval', TimeCell,
        'startTime', StartTime,
    	'endTime', EndTime,
        'temperature',  Temperature,
	'rain',  Rain,
	'wind',  Wind, 
	'humidity', Humidity,
	'pm25',  PM25) AS Attributes
FROM WeatherPM 
ORDER BY TripId, IniTime asc);

 
 