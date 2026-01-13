DROP TABLE IF EXISTS Grid;
CREATE TABLE Grid(CellId integer PRIMARY KEY, Box stbox);
INSERT INTO Grid(CellId, Box)
WITH MBR(Box) AS (
  SELECT extent(Geom::stbox)
  FROM DelhiInput )
SELECT (rec).Index, (rec).Tile
FROM ( SELECT spaceTiles(Box, 2500) AS rec FROM MBR );

-- Time: 2914.240 ms (00:02.914)

CREATE INDEX Grid_quadtree_idx ON Grid USING SPGIST(Box);

-- Time: 12.635 ms

DROP TABLE IF EXISTS PM25Hourly;
CREATE TABLE PM25Hourly(CellId integer, DateHour tstzspan, Pm2_5 float);
INSERT INTO PM25Hourly
SELECT g.CellId, span(date_trunc('hour', d.T), date_trunc('hour', d.T) + '1 hour'),
  AVG(Pm2_5)
FROM Grid g, DelhiInput d
WHERE g.Box @> stbox(d.Geom)
GROUP BY g.CellId, date_trunc('hour', d.T)
ORDER BY g.CellId, date_trunc('hour', d.T);

-- Time: 94123.565 ms (01:34.124)

DROP TABLE IF EXISTS WeatherHourly;
CREATE TABLE WeatherHourly(Time timestamptz PRIMARY KEY, Temperature float,
  Humidity float, CloudCover float, Rain float, Wind float,  TimeSpan tstzspan);
COPY WeatherHourly (Time, Temperature, Humidity, CloudCover, Rain, Wind) 
FROM '/.../delhiRainTempHumid.csv' DELIMITER ';' CSV HEADER;

-- Time: 13.083 ms
 
UPDATE WeatherHourly SET TimeSpan = span(Time, Time + interval '1 hour');

DROP TABLE IF EXISTS SemTrajJSON;
CREATE TABLE SemTrajJSON AS
WITH TripCells(TripId, CellId, TripCell) AS (
  SELECT TripId, CellId, unnest(sequences(atStbox(d.Trip, g.Box)))
  FROM DelhiTrips d, Grid g
  WHERE atStbox(d.Trip, g.Box) IS NOT NULL
  ORDER BY TripId, CellId ),
TimeCells(TripId, CellId, TripCell, TimeCell, TripCellTraj) AS (
  SELECT TripId, CellId, TripCell, getTime(TripCell)::tstzspan, trajectory(TripCell)
  FROM TripCells
  ORDER BY TripId, CellId ),
WeatherPM(TripId, CellId, TripCell, TimeCell, TripCellTraj,
    Temperature, Time, Rain, Wind, Humidity, CloudCover, Pm2_5) AS (
  SELECT t.TripId, t.CellId, t.TripCell, t.TimeCell, t.TripCellTraj,
    w.Temperature, w.Time, w.Rain, w.Wind, w.Humidity, w.CloudCover, Pm2_5
  FROM TimeCells t, WeatherHourly w, PM25Hourly p
  WHERE w.TimeSpan && t.TimeCell AND t.CellId = p.CellId AND w.TimeSpan && p.DateHour )
SELECT TripId, CellId, TripCell, TimeCell, TripCellTraj,
  jsonb_build_object('cellId', CellId, 'cellInterval', TimeCell,
    'temperature', Temperature, 'rain', Rain, 'wind', Wind, 'humidity',
    Humidity, 'cloudCover', CloudCover, 'pm25', Pm2_5) AS Attributes
FROM WeatherPM
ORDER BY TripId, TripCell;

-- Time: 183156.944 ms (03:03.157)