SELECT MMSI, DATE_TRUNC('hour', t) AS Hour,
  ST_Centroid(ST_Collect(ARRAY_AGG(geom))) AS Centroid
FROM AISInput
GROUP BY MMSI, hour
ORDER BY MMSI, hour;
