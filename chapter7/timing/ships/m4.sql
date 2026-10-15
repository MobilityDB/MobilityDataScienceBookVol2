WITH AlertBelt(Belt) AS (
SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487))
SELECT MMSI, atGeometry(s.Trip, b.Belt),
 ST_AsText(trajectory(atGeometry(s.Trip,  b.Belt))) as traj
FROM ships s, AlertBelt b
WHERE eintersects(s.Trip, b.Belt);
