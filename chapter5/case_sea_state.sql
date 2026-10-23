/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- Case study, Sea State: the hourly significant wave height of WaveHeight
-- (load_waves.sh) read along every trip, the speed of the vessels in higher
-- waves, and the highest waves of the day computed by map algebra over the
-- hours. Each listing of the chapter is preceded by its printed answer; the
-- other queries give the numbers stated in the text. check_wave_overlap.sh
-- compares the two wave products where they overlap.
\pset footer off
SET TimeZone = 'UTC';
SET client_min_messages = warning;

\echo == mean and highest wave height of the field per hour (0.93 in the morning, 1.36 and 3.68 at 23:00)
SELECT to_char(lower(ValidTime), 'HH24:MI') AS Hour,
  round((ST_SummaryStatsAgg(Rast, 1, true)).mean::numeric, 2) AS MeanHs,
  round((ST_SummaryStatsAgg(Rast, 1, true)).max::numeric, 2) AS MaxHs
FROM WaveHeight
GROUP BY lower(ValidTime)
ORDER BY lower(ValidTime);

\echo == Query: vessels that met waves of at least 1, 1.5, and 2 m, and for how long
-- 2592 | 465 | 106 | 29 | 2.71
DROP TABLE IF EXISTS SeaState;
CREATE TABLE SeaState AS
SELECT s.MMSI, mergeAgg(rasterValue(atTime(s.Trip, w.ValidTime), w.Rast)
  ORDER BY w.ValidTime) AS WaveHeight
FROM Ships s, WaveHeight w
WHERE s.Trip && w.ValidTime AND ST_Intersects(w.Rast, trajectory(s.Trip))
GROUP BY s.MMSI;
SELECT COUNT(*) AS Vessels,
  COUNT(*) FILTER (WHERE maxValue(WaveHeight) >= 1) AS Over1,
  COUNT(*) FILTER (WHERE maxValue(WaveHeight) >= 1.5) AS Over15,
  COUNT(*) FILTER (WHERE maxValue(WaveHeight) >= 2) AS Over2,
  round(MAX(maxValue(WaveHeight))::numeric, 2) AS MaxHs
FROM SeaState;
/* MMSI      | MaxHs | Over2
   257243000 |  2.65 | 05:29:41
   314545000 |  2.23 | 04:11:14
   219438000 |  2.45 | 03:59:52 */
SELECT MMSI, round(maxValue(WaveHeight)::numeric, 2) AS MaxHs,
  duration(whenTrue(WaveHeight #>= 2)) AS Over2
FROM SeaState
WHERE maxValue(WaveHeight) >= 2
ORDER BY duration(whenTrue(WaveHeight #>= 2)) DESC
LIMIT 3;
\echo == the 29 vessels that met waves of at least 2 m: longitudes of their highest waves, and how many after 20:00 (3.2 | 7.3 | 24)
SELECT COUNT(*) AS Vessels,
  round(MIN(ST_X(valueAtTimestamp(s.TripLonLat, startTimestamp(atMax(w.WaveHeight)))))::numeric, 1)
    AS MinLon,
  round(MAX(ST_X(valueAtTimestamp(s.TripLonLat, startTimestamp(atMax(w.WaveHeight)))))::numeric, 1)
    AS MaxLon,
  COUNT(*) FILTER (WHERE startTimestamp(atMax(w.WaveHeight)) >= '2026-01-20 20:00+00')
    AS After20
FROM SeaState w JOIN Ships s USING (MMSI)
WHERE maxValue(w.WaveHeight) >= 2;

\echo == Query: did the vessels that met waves of at least 1.5 m sail slower in them
/* ShipType | Vessels | SogHigh | SogLow | Slower | Faster
   Cargo    |      15 |    10.5 |   11.3 |      3 |      1
   Tanker   |      16 |    10.7 |   11.3 |      4 |      0
   ...
            |      39 |    10.0 |   10.5 |      7 |      4 */
DROP TABLE IF EXISTS SpeedWaves;
CREATE TABLE SpeedWaves AS
WITH Rough AS (
  SELECT MMSI, WaveHeight FROM SeaState
  WHERE maxValue(WaveHeight) >= 1.5 ),
Speed AS (
  SELECT s.MMSI, s.SOG, v.ShipType
  FROM Ships s JOIN Vessels v USING (MMSI) )
SELECT r.MMSI, s.ShipType,
  twAvg(atTime(s.SOG, whenTrue(r.WaveHeight #>= 1.5) * whenTrue(s.SOG #> 3)))
    AS SogHigh,
  twAvg(atTime(s.SOG, whenTrue(r.WaveHeight #< 1.5) * whenTrue(s.SOG #> 3)))
    AS SogLow,
  duration(whenTrue(r.WaveHeight #>= 1.5) * whenTrue(s.SOG #> 3)) AS TimeHigh,
  duration(whenTrue(r.WaveHeight #< 1.5) * whenTrue(s.SOG #> 3)) AS TimeLow
FROM Rough r JOIN Speed s USING (MMSI);
SELECT ShipType, COUNT(*) AS Vessels,
  round(AVG(SogHigh)::numeric, 1) AS SogHigh,
  round(AVG(SogLow)::numeric, 1) AS SogLow,
  COUNT(*) FILTER (WHERE SogHigh < 0.9 * SogLow) AS Slower,
  COUNT(*) FILTER (WHERE SogHigh > 1.1 * SogLow) AS Faster
FROM SpeedWaves
WHERE TimeHigh >= interval '30 minutes' AND TimeLow >= interval '30 minutes'
GROUP BY ROLLUP (ShipType)
ORDER BY ShipType NULLS LAST;

\echo == Query: vessels flagged by the highest waves of the day read along their trajectories
-- 2592 | 715 | 237 | 63
DROP TABLE IF EXISTS WaveMax;
CREATE TABLE WaveMax AS
SELECT ST_Union(Rast, 'MAX') AS Rast
FROM WaveHeight
GROUP BY ST_UpperLeftX(Rast), ST_UpperLeftY(Rast);
SELECT COUNT(*) AS Vessels,
  COUNT(*) FILTER (WHERE maxValue(Hs) >= 1) AS Over1,
  COUNT(*) FILTER (WHERE maxValue(Hs) >= 1.5) AS Over15,
  COUNT(*) FILTER (WHERE maxValue(Hs) >= 2) AS Over2
FROM (
  SELECT s.MMSI, mergeAgg(rasterValue(s.Trip, w.Rast)) AS Hs
  FROM Ships s, WaveMax w
  WHERE ST_Intersects(w.Rast, trajectory(s.Trip))
  GROUP BY s.MMSI ) t;
\echo == tiles of the table WaveMax (48)
SELECT COUNT(*) AS Tiles FROM WaveMax;
