WITH Goteborg(GotEnv) AS (
  SELECT ST_MakeEnvelope(666538, 6392057, 679171, 6403745))
SELECT s.MMSI,
ST_AsText(trajectory(atGeometry(s.Trip,  g.GotEnv))) as traj, g.GotEnv
FROM Goteborg g, Ships s
WHERE eIntersects(s.Trip, g.GotEnv);
