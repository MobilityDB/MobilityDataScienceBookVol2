WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 500) AS buf
  FROM Port )
SELECT s.MMSI, ST_AsText(trajectory(s.Trip)) AS trip_wkt,
    ST_AsWKB(pb.buf) AS buffer_wkb
FROM Ships s, PortBuffer pb
WHERE eIntersects(s.Trip, pb.buf);
