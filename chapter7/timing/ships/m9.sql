WITH Port AS (
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
