-- Section 8: reported speed of the vessels under way while in waves of at
-- least 1.5 m and while in lower waves, for the vessels that met such waves.
\pset footer off
\timing on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS SpeedWaves;
CREATE TABLE SpeedWaves AS
WITH Rough AS (
  SELECT MMSI, WaveHeight FROM SeaState WHERE maxValue(WaveHeight) >= 1.5 ),
Speed AS (
  SELECT a.MMSI, tfloatSeqSetGaps(array_agg(tfloat(a.SOG, a.T) ORDER BY a.T)
    FILTER (WHERE a.SOG IS NOT NULL), interval '3 minutes') AS SOG,
    mode() WITHIN GROUP (ORDER BY a.ShipType) AS ShipType
  FROM AISNoJump a JOIN Rough r USING (MMSI)
  GROUP BY a.MMSI )
SELECT r.MMSI, s.ShipType,
  twAvg(atTime(s.SOG, whenTrue(r.WaveHeight #>= 1.5) * whenTrue(s.SOG #> 3))) AS SogHigh,
  twAvg(atTime(s.SOG, whenTrue(r.WaveHeight #< 1.5) * whenTrue(s.SOG #> 3))) AS SogLow,
  duration(whenTrue(r.WaveHeight #>= 1.5) * whenTrue(s.SOG #> 3)) AS TimeHigh,
  duration(whenTrue(r.WaveHeight #< 1.5) * whenTrue(s.SOG #> 3)) AS TimeLow
FROM Rough r JOIN Speed s USING (MMSI);

\echo == vessels under way both in and out of waves of 1.5 m, by ship type
SELECT ShipType, count(*) AS Vessels,
  round(avg(SogHigh)::numeric, 1) AS SogHigh, round(avg(SogLow)::numeric, 1) AS SogLow,
  count(*) FILTER (WHERE SogHigh < 0.9 * SogLow) AS Slower,
  count(*) FILTER (WHERE SogHigh > 1.1 * SogLow) AS Faster
FROM SpeedWaves
WHERE TimeHigh >= interval '30 minutes' AND TimeLow >= interval '30 minutes'
GROUP BY ROLLUP (ShipType)
ORDER BY ShipType NULLS LAST;
