-- The values chapter 7 prints for the MobilityDuck AIS queries, from ${CH7_DB_DIR}/ships.duckdb, with
-- the vessel names read from the table Vessels of the PostgreSQL database ais.
INSTALL postgres;
LOAD spatial;
LOAD '${MOBILITYDUCK_EXTENSION}';
LOAD postgres;
CREATE TEMP TABLE V AS SELECT MMSI, Name, ShipType FROM postgres_scan('${PG_AIS}', 'public', 'vessels');
.print == hours
WITH Hours AS (
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
.print == rodby ferries
WITH Ports(Rodby, Puttgarden) AS
  (SELECT ST_MakeEnvelope(651135, 6058230, 651422, 6058548),
    ST_MakeEnvelope(644339, 6042108, 644896, 6042487))
SELECT s.MMSI, V.Name FROM Ports p, Ships s LEFT JOIN V USING (MMSI)
WHERE eintersects(trip, p.Rodby) AND eintersects(trip, p.Puttgarden) ORDER BY ALL;
.print == buffer500
WITH Port AS (SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom),
PortBuffer AS (SELECT ST_Buffer(port_geom, 500) AS buf FROM Port)
SELECT s.MMSI, V.Name, V.ShipType FROM Ships s LEFT JOIN V USING (MMSI), PortBuffer pb
WHERE eIntersects(s.Trip, pb.buf) ORDER BY ALL;
.print == stops1000
WITH Port AS (SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom),
PortBuffer AS (SELECT ST_Buffer(port_geom, 1000) AS buf FROM Port)
SELECT s.MMSI, V.Name, V.ShipType FROM ships s LEFT JOIN V USING (MMSI), PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
  astext(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes')) IS NOT NULL ORDER BY ALL;
