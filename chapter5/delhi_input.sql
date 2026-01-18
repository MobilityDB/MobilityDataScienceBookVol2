DO $$
DECLARE
  filePath text = '/home/esteban/data/delhi/';
  fileName text;
  fileNames text[];
BEGIN
  CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

  SET TIMEZONE TO 'Asia/Kolkata';

  DROP TABLE IF EXISTS DelhiInput;
  CREATE TABLE DelhiInput (
    Id int NOT NULL,
    UId text PRIMARY KEY,
    T timestamptz NOT NULL,
    DeviceId text NOT NULL,
    Lat double precision NOT NULL,
    Lon double precision NOT NULL,
    Pm1_0 double precision NOT NULL,
    Pm2_5 double precision NOT NULL,
    Pm10 double precision NOT NULL,
    Geom geometry,
    UNIQUE(DeviceId, T)
  );

  SELECT array_agg(f ORDER BY f) INTO fileNames
  FROM pg_ls_dir(filePath) AS f
  WHERE f ~* '^2020.*\.csv$';   -- case-insensitive regex
  FOREACH fileName IN ARRAY fileNames
  LOOP
    EXECUTE format(
      'COPY DelhiInput(Id, UId, T, DeviceId, Lat, Lon, Pm1_0, Pm2_5, Pm10) '
      'FROM %L WITH DELIMITER '','' CSV HEADER', filePath || fileName);
    COMMIT;
    RAISE NOTICE 'Inserting %', fileName;
  END LOOP;

  UPDATE DelhiInput
  SET Geom = ST_Transform(ST_Point(Lon, Lat, 4326), 7760);

  DROP TABLE IF EXISTS DelhiTrips;
  CREATE TABLE DelhiTrips(
    TripId integer PRIMARY KEY,
    DeviceId text,
    Trip tgeompoint,
    Trajectory geometry,
    Pm1_0 tfloat,
    Pm2_5 tfloat,
    Pm10 tfloat
  );

  INSERT INTO DelhiTrips(TripId, DeviceId, Trip, Trajectory, Pm1_0, Pm2_5, Pm10)
  WITH DelhiStart AS (
    SELECT d.*,
      CASE WHEN LAG(T) OVER w IS NULL OR T - LAG(T) OVER w > '5 minutes' OR
        ST_Distance(Geom, LAG(Geom) OVER w) > 1000 THEN 1
      END AS StartInst
    FROM DelhiInput d
    WINDOW w AS (PARTITION BY DeviceId ORDER BY T) ),
  DelhiGroup AS (
    SELECT d.*, COUNT(StartInst) OVER (ORDER BY DeviceId, T) AS TripId
    FROM DelhiStart d ),
  Trips(TripId, DeviceId, Trip, Pm1_0, Pm2_5, Pm10) AS (
    SELECT TripId, DeviceId,
      tgeompointSeq(array_agg(tgeompoint(d.Geom, d.T) ORDER BY d.T)),
      tfloatSeq(array_agg(tfloat(d.Pm1_0, d.T) ORDER BY d.T)),
      tfloatSeq(array_agg(tfloat(d.Pm2_5, d.T) ORDER BY d.T)),
      tfloatSeq(array_agg(tfloat(d.Pm10, d.T) ORDER BY d.T))
    FROM DelhiGroup d
    GROUP BY TripId, DeviceId )
  SELECT TripId, DeviceId, Trip, trajectory(Trip), Pm1_0, Pm2_5, Pm10
  FROM Trips;

  CREATE INDEX DelhiTrips_Trip_Quadtree_Idx ON DelhiTrips USING SPGIST(Trip);

END $$;

