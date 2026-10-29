select count(*)
FROM aisinput;
--18 secs 608 msec.

SELECT
    MMSI,
    COUNT(*) AS message_count
    FROM AISInput
    GROUP BY MMSI
    ORDER BY message_count DESC;

--19 secs 985 msec.

SELECT
    MMSI,
    MIN(t) AS first_seen,
    MAX(t) AS last_seen
    FROM AISInput
    GROUP BY MMSI
    ORDER BY last_seen;

-- 20 secs 340 msec.

SELECT
    MMSI,
    AVG(SOG) AS avg_speed,
    MAX(SOG) AS max_speed
FROM AISInput
GROUP BY MMSI
ORDER BY avg_speed DESC;

--30 secs 312 msec.

SELECT
    MMSI,
    COUNT(DISTINCT DATE_TRUNC('hour', t)) AS active_hours
FROM AISInput
GROUP BY MMSI
ORDER BY active_hours DESC;

-- 2 min 16 secs.3169 rows affected.

SELECT
    ST_Extent(geom) AS bbox
FROM AISInput;
-- 34 secs 368 msec.

SELECT
    MIN(Latitude)  AS min_lat,
    MAX(Latitude)  AS max_lat,
    MIN(Longitude) AS min_lon,
    MAX(Longitude) AS max_lon
FROM AISInput;
-- Total query runtime: 25 secs 486 msec.

--Ships within 1000 m using a buffer geometry
 WITH target AS (
    SELECT Geom, t
    FROM AISInput
    WHERE MMSI = 232043744
    ORDER BY t DESC
    LIMIT 1
)
SELECT other.MMSI, other.t, ST_AsText(other.Geom) AS Geom
FROM AISInput other, target t
WHERE other.MMSI <> 232043744
  AND ST_Distance (other.Geom::geography, t.Geom::geography) <= 1000
  AND ABS(EXTRACT(EPOCH FROM (other.t - t.t))) <= 60; 
-- 1 minute 25=6 seconds  


--For every ship, count neighbors within 1000 m (latest position)
WITH Latest AS (
    SELECT MMSI, geom, t
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI ORDER BY t 
        	DESC) AS rn
        FROM AISInput
    )
    WHERE rn = 1
),
Neighbors AS (
    SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2
    FROM latest l1, latest l2
    WHERE l1.MMSI <> l2.MMSI
      AND ST_Distance (l1.Geom::geography, l2.Geom::geography) <= 1000
      AND ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60
)
SELECT l.MMSI, ST_AsText(l.Geom) AS Geom,
       COUNT(n.MMSI2) AS NeighborCount
FROM latest l
LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1
GROUP BY l.MMSI, l.Geom
ORDER BY NeighborCount DESC; 

-- 

-- 5-NN of this ship considering space and time.

WITH Latest AS (
    SELECT MMSI, geom, t
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY MMSI ORDER BY t 
        	DESC) AS rn
        FROM AISInput
    )
    WHERE rn = 1
),
Neighbors AS (
    SELECT l1.MMSI AS MMSI1, l2.MMSI AS MMSI2
    FROM latest l1, latest l2
    WHERE l1.MMSI <> l2.MMSI
      AND ST_Distance (l1.Geom::geography, l2.Geom::geography) <= 1000
      AND ABS(EXTRACT(EPOCH FROM (l1.t - l2.t))) <= 60
)
SELECT l.MMSI, ST_AsText(l.Geom) AS Geom,
       COUNT(n.MMSI2) AS NeighborCount
FROM latest l
LEFT JOIN Neighbors n ON l.MMSI = n.MMSI1
GROUP BY l.MMSI, l.Geom
ORDER BY NeighborCount DESC; 
--   
 