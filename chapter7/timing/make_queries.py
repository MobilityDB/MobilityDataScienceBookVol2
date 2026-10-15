"""Write the MobilityDuck listings of Chapter 7 and their MobilityDB twins as SQL files.

ships/mN.sql are the queries of the AIS use case of MobilityDuck (over the table Ships) as the
chapter prints them, and ships/pg_mN.sql their MobilityDB twins: the envelopes and points carry
the SRID of the trajectories (EPSG:25832), ST_AsWKB is written ST_AsBinary, and, since
PostgreSQL has no reservoir sampling, the sample of DuckDB is read from the table SampleN that
ships_sample.sh fills with the ships DuckDB draws. In the two sampled queries the size of the
sample is the placeholder NSAMPLE, which bench.py substitutes.

hanoi/hN.sql are the queries of the BerlinMOD-Hanoi use case as the chapter prints them, and
hanoi/pg_hN.sql their MobilityDB twins: integer division is written `/`, and the two subqueries
that take a thousand trips take the first thousand in TripId order, the order in which
hanoi_duckdb.sql loads the DuckDB table. The tables Bins and Trips200 that two of the listings
create are created by hanoi_duckdb.sql and hanoi_pg.sql.

usage: python3 make_queries.py
"""
import os
import re

D = os.path.dirname(os.path.abspath(__file__))

SHIPS = {}
SHIPS[1] = """WITH Hours AS (
  SELECT TIMESTAMPTZ '2026-01-20 13:00:00+00' AS hour_start
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 14:00:00+00'
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 15:00:00+00'
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 16:00:00+00'
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 17:00:00+00'
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 18:00:00+00'
  UNION ALL SELECT TIMESTAMPTZ '2026-01-20 19:00:00+00' )
SELECT h.hour_start, COUNT(DISTINCT s.MMSI) AS num_ships
FROM Hours h, Ships s
WHERE atTime(s.Trip, h.hour_start) IS NOT NULL
GROUP BY h.hour_start
ORDER BY h.hour_start;
"""
SHIPS[2] = """WITH Goteborg(GotEnv) AS (
  SELECT ST_MakeEnvelope(666538, 6392057, 679171, 6403745))
SELECT s.MMSI,
ST_AsText(trajectory(atGeometry(s.Trip,  g.GotEnv))) as traj, g.GotEnv
FROM Goteborg g, Ships s
WHERE eIntersects(s.Trip, g.GotEnv);
"""
SHIPS[3] = """WITH Ports(Rodby, Puttgarden) AS
 (SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548),
     ST_MakeEnvelope(644339, 6042108, 644896, 6042487))
SELECT s.MMSI, ST_AsText(trajectory(trip)) AS Trajectory,
 Rodby, Puttgarden
FROM Ports p, Ships s
WHERE eintersects(trip, p.Rodby) AND eintersects(trip, p.Puttgarden);
"""
SHIPS[4] = """WITH AlertBelt(Belt) AS (
SELECT ST_MakeEnvelope(640730, 6058230, 654100, 6042487))
SELECT MMSI, atGeometry(s.Trip, b.Belt),
 ST_AsText(trajectory(atGeometry(s.Trip,  b.Belt))) as traj
FROM ships s, AlertBelt b
WHERE eintersects(s.Trip, b.Belt);
"""
SHIPS[5] = """WITH Timespan(Period) AS (
 SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
 SELECT MMSI, atTime(s.Trip, t.Period)
 FROM Ships s TABLESAMPLE RESERVOIR (NSAMPLE ROWS) REPEATABLE (1),
   Timespan t
 WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
TimeClosestShips(MMSI1, MMSI2, ClosestDist, TimeAtClosestDist, Trip1, Trip2) AS (
 SELECT s1.MMSI, s2.MMSI, startValue(atMin(s1.Trip <-> s2.Trip)),
  startTimestamp(atMin(s1.Trip <-> s2.Trip)), s1.Trip, s2.Trip
 FROM TimeShips s1, TimeShips s2
 WHERE s1.MMSI < s2.MMSI AND CASE WHEN eDwithin(s1.Trip, s2.Trip, 300)
  THEN startValue(atMin(s1.Trip <-> s2.Trip)) < 300 END )
SELECT t.MMSI1, t.MMSI2, t.ClosestDist, t.TimeAtClosestDist,
 valueAtTimestamp(Trip1, TimeAtClosestDist) AS Point1,
 valueAtTimestamp(Trip2, TimeAtClosestDist) AS Point2
FROM TimeClosestShips t;
"""
SHIPS[6] = """WITH Timespan(Period) AS (
 SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
TimeShips(MMSI, Trip) AS (
 SELECT MMSI, atTime(s.Trip, t.Period)
 FROM Ships s TABLESAMPLE RESERVOIR (NSAMPLE ROWS) REPEATABLE (1),
   Timespan t
 WHERE atTime(s.Trip, t.Period) IS NOT NULL )
SELECT s1.MMSI, s2.MMSI, s1.Trip, s2.Trip,
 ST_AsText(trajectory(s1.Trip)) as traj1,
 ST_AsText(trajectory(s2.Trip)) as traj2
FROM TimeShips s1, TimeShips s2
WHERE s1.MMSI < s2.MMSI AND eDwithin(s1.Trip, s2.Trip, 300)  ;
"""
SHIPS[7] = """WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 500) AS buf
  FROM Port )
SELECT s.MMSI, ST_AsText(trajectory(s.Trip)) AS trip_wkt,
    ST_AsWKB(pb.buf) AS buffer_wkb
FROM Ships s, PortBuffer pb
WHERE eIntersects(s.Trip, pb.buf);
"""
SHIPS[8] = """WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 1000) AS buf
  FROM Port )
SELECT s.MMSI,
   asText(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes')),
   ST_AsText(trajectory(atGeometry(s.trip, pb.buf)))
   AS tripWkt, ST_AsWKB(pb.buf) AS bufferWkb
FROM ships s, PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
 astext(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes'))
 IS NOT NULL;
"""
SHIPS[9] = """WITH Port AS (
  SELECT ST_Point(752775.9137447166, 6167956.005944439) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 5000) AS buf
  FROM Port )
SELECT s.MMSI,
  asText(stops(atGeometry(s.trip, pb.buf),1000.0, interval '1 hour')),
  ST_AsText(trajectory(atGeometry(s.trip,   pb.buf)))
  AS tripWkt, ST_AsWKB(pb.buf) AS buffer_wkb,
  startTimestamp(stops(atGeometry(s.trip, pb.buf),1000.0,
  interval '1 hour')) AS start_time
FROM Ships s, PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
  astext(stops(atGeometry(s.trip, pb.buf),1000.0, interval '1 hour'))
  IS NOT NULL;
"""

HANOI = {}
HANOI[1] = """WITH tripInt AS
 (SELECT vehicleid, tripid,
         COUNT(DISTINCT m.municipalityid) AS intersectCount
  FROM trips t, municipalities m
  WHERE eintersects(trip, municipalitygeo)
GROUP BY vehicleid, tripid)
SELECT t1.*, ST_AsText(t.trajectory) AS trajectory
FROM trips t JOIN tripInt t1 ON (t.tripId = t1.tripId AND t.vehicleid = t1.vehicleid)
ORDER BY intersectCount DESC
LIMIT 1;
"""
HANOI[2] = """select municipalityid, municipalityname,
  COUNT(*) as intersectCount
from trips t, municipalities m
where eintersects(t.trip, m.municipalitygeo)
group by municipalityid, municipalityname
order by intersectCount desc;
"""
HANOI[3] = """SELECT m.MunicipalityName,
  round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)
    ::numeric, 3) AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo)
GROUP BY m.MunicipalityName;
"""
HANOI[4] = """SELECT DISTINCT t1.VehicleId AS VehicleId1, t1.TripId AS TripId1,
  ST_AsText(t1.Trajectory) AS Traj1, t2.VehicleId AS VehicleId2, t2.TripId AS TripId2,
  ST_AsText(t2.Trajectory) AS Traj2
FROM (SELECT * FROM trips t1 LIMIT 1000) t1,
  (SELECT * FROM trips t2 LIMIT 1000) t2
WHERE t1.VehicleId < t2.VehicleId AND eDwithin(t1.Trip, t2.Trip, 10.0)
ORDER BY t1.VehicleId, t2.VehicleId;
"""
HANOI[5] = """WITH TripsTraj AS(
  SELECT TripId, VehicleId, Trajectory
  FROM Trips ),
PointTrips AS(
  SELECT P.PointId, T2.VehicleId, T2.TripId, T2.Distance
  FROM Points P, LATERAL (
    SELECT T1.VehicleId, T1.TripId,
      ST_Distance(P.geom, T1.Trajectory) AS Distance
    FROM TripsTraj T1
    ORDER BY Distance LIMIT 3 ) AS T2 )
SELECT T.TripId, T.VehicleId, P.PointId, PT.Distance
FROM Trips T  JOIN PointTrips PT ON
    (T.VehicleId = PT.VehicleId  AND T.TripId = PT.TripId)
       JOIN Points P ON P.PointId = PT.PointId
ORDER BY T.VehicleId, T.TripId, P.PointId;
"""
HANOI[6] = """WITH TripPeriod AS(
  SELECT tripid, pId, p.SpanP, vehicleid, atTime(T.Trip, P.SpanP) as tripPeriod
  FROM Trips T, Bins P
  WHERE T.Trip && P.SpanP)
SELECT T.Pid as intervalId, T.SpanP as intervalTime, M.municipalityName as
  Municipality, COUNT(*) as tripsCount
FROM TripPeriod T, Municipalities M
WHERE eintersects(TripPeriod, M.MunicipalityGeo)
GROUP BY T.Pid,T.SpanP,  M.municipalityName
ORDER BY COUNT(*) desc, M.municipalityName,T.Pid;
"""
HANOI[7] = """WITH Temp AS (
  SELECT l1.Licence AS Licence1,
    t2.VehicleId AS Car2Id,
    whenTrue(tDwithin(t1.Trip, t2.Trip, 3.0)) AS Periods
  FROM Trips t1, Licences1 l1, Trips t2, Vehicles v
  WHERE t1.VehicleId = l1.VehicleId AND
    t2.VehicleId = v.VehicleId AND
    t1.VehicleId <> t2.VehicleId AND
    t2.Trip && expandSpace(t1.trip::STBOX, 3.0) )
SELECT Licence1, Car2Id, Periods
FROM Temp
WHERE Periods IS NOT NULL;
"""
HANOI[8] = """SELECT T1.tripid, T1.VehicleId AS VehId1, C2.VehicleId AS VehId2, C2.Distance
FROM Trips200 T1, LATERAL (
  SELECT T2.VehicleId, minValue(T1.Trip <-> T2.Trip) AS Distance
  FROM Trips200 T2
  WHERE T1.VehicleId < T2.VehicleId AND TimeSpan(T1.Trip) && TimeSpan(T2.Trip)
  ORDER BY Distance LIMIT 3 ) AS C2
ORDER BY T1.tripid, T1.VehicleId, C2.Distance, C2.VehicleId;
"""
HANOI[9] = """WITH Groups AS (
 SELECT ((ROW_NUMBER() OVER (ORDER BY V.Vehicleid))-1)//10 + 1 AS GroupId,
  V.Vehicleid
 FROM Vehicles V ),
SumDistances AS (
 SELECT G.GroupId, P.PointId,
   SUM(ST_Distance(T.trajectory, P.Geom)) AS SumDist
 FROM Groups G, Points P, Trips T
 WHERE T.Vehicleid = G.Vehicleid
 GROUP BY G.GroupId, P.PointId )
SELECT S1.GroupId, S1.PointId, S1.SumDist
FROM SumDistances S1
WHERE S1.SumDist <= ALL (
  SELECT SumDist
  FROM SumDistances S2
  WHERE S1.GroupId = S2.GroupId )
ORDER BY S1.GroupId, S1.PointId;
"""
HANOI[10] = """SELECT DISTINCT t.TripId, v.Licence, p.PointId, st_astext(p.Geom),
  startTimestamp(atValue(t.Trip, p.Geom))  AS Instant,
  ST_AsText(t.trajectory) as trajectory
FROM Trips t, Vehicles v, Points p
WHERE t.VehicleId = v.VehicleId AND v.VehicleType = 'passenger' AND
  eIntersects(t.Trip, ST_Buffer(p.Geom,10));
"""
HANOI[11] = """WITH Timestamps AS (
  SELECT DISTINCT  v.Licence, p.pointId, p.Geom,
    MIN(startTimestamp(atValue(t.Trip, p.Geom))) AS Instant
  FROM Trips t, Vehicles v, Points p
  WHERE t.VehicleId = v.VehicleId AND
    v.VehicleType = 'passenger' AND eIntersects(t.Trip, p.Geom)
  GROUP BY v.Licence, p.pointId, p.Geom )
SELECT t1.*
FROM Timestamps t1
WHERE t1.Instant <= ALL (
  SELECT t2.Instant
  FROM Timestamps t2
  WHERE t1.PointId = t2.PointId )
ORDER BY t1.PointId, t1.Licence;
"""

for n, sql in SHIPS.items():
    pg = re.sub(r'ST_MakeEnvelope\(([^()]*)\)', r'ST_MakeEnvelope(\1, 25832)', sql)
    pg = re.sub(r'ST_Point\(([^()]*)\)', r'ST_Point(\1, 25832)', pg)
    pg = pg.replace('ST_AsWKB(', 'ST_AsBinary(').replace(
        'TABLESAMPLE RESERVOIR (NSAMPLE ROWS) REPEATABLE (1)', 'JOIN SampleNSAMPLE USING (MMSI)')
    open(os.path.join(D, f'ships/m{n}.sql'), 'w').write(sql)
    open(os.path.join(D, f'ships/pg_m{n}.sql'), 'w').write(pg)
for n, sql in HANOI.items():
    pg = sql.replace(')//10', ')/10').replace('LIMIT 1000)', 'ORDER BY TripId LIMIT 1000)')
    open(os.path.join(D, f'hanoi/h{n}.sql'), 'w').write(sql)
    open(os.path.join(D, f'hanoi/pg_h{n}.sql'), 'w').write(pg)
