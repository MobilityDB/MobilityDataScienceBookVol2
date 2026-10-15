WITH Port AS (
  SELECT ST_Point(726765.3929300838, 6178705.65508127, 25832) AS port_geom ),
PortBuffer AS (
  SELECT ST_Buffer(port_geom, 1000) AS buf
  FROM Port )
SELECT s.MMSI,
   asText(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes')),
   ST_AsText(trajectory(atGeometry(s.trip, pb.buf)))
   AS tripWkt, ST_AsBinary(pb.buf) AS bufferWkb
FROM ships s, PortBuffer pb
WHERE eIntersects(s.trip, pb.buf) AND
 astext(stops(atGeometry(s.trip, pb.buf),10.0, interval '20 minutes'))
 IS NOT NULL;
