WITH Ports(Rodby, Puttgarden) AS
 (SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548),
     ST_MakeEnvelope(644339, 6042108, 644896, 6042487))
SELECT s.MMSI, ST_AsText(trajectory(trip)) AS Trajectory,
 Rodby, Puttgarden
FROM Ports p, Ships s
WHERE eintersects(trip, p.Rodby) AND eintersects(trip, p.Puttgarden);
