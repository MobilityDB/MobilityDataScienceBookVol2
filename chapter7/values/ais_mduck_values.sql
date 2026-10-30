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
.print == close300 and close600: ships of the sample in the period, pairs, answer, pairs in the Esbjerg detail
-- The sample of TABLESAMPLE RESERVOIR ... REPEATABLE (1) depends on the order of the rows of Ships,
-- which load/ships_duckdb.sql loads ORDER BY MMSI, as the chapter's listing does. The Esbjerg detail
-- is the frame of the map pointsclose300_b of figures/fig_md.py: centre 55.4742 N, 8.4235 E, zoom 16,
-- 732 x 862 pixels, in Web Mercator.
CREATE TEMP MACRO lonlat_pt(g) AS ST_Transform(g, 'EPSG:25832', 'EPSG:4326', true);
WITH Frame AS (
  SELECT 8.4235 - 366 * 360.0 / (256 * 2^16) AS x0, 8.4235 + 366 * 360.0 / (256 * 2^16) AS x1,
    degrees(atan(sinh(pi() * (1 - 2 * ((1 - ln(tan(radians(55.4742)) + 1 / cos(radians(55.4742)))
      / pi()) / 2 * 256 * 2^16 + 431) / (256 * 2^16))))) AS y0,
    degrees(atan(sinh(pi() * (1 - 2 * ((1 - ln(tan(radians(55.4742)) + 1 / cos(radians(55.4742)))
      / pi()) / 2 * 256 * 2^16 - 431) / (256 * 2^16))))) AS y1 ),
Timespan(Period) AS (
  SELECT tstzspan '[2026-01-20 11:00:00+00, 2026-01-20 23:30:00+00)' ),
Sample AS (
  SELECT 300 AS N, MMSI, Trip FROM Ships TABLESAMPLE RESERVOIR (300 ROWS) REPEATABLE (1)
  UNION ALL
  SELECT 600, MMSI, Trip FROM Ships TABLESAMPLE RESERVOIR (600 ROWS) REPEATABLE (1) ),
TimeShips(N, MMSI, Trip) AS (
  SELECT N, MMSI, atTime(s.Trip, t.Period) FROM Sample s, Timespan t
  WHERE atTime(s.Trip, t.Period) IS NOT NULL ),
Pairs AS (
  SELECT s1.N, startTimestamp(atMin(s1.Trip <-> s2.Trip)) AS T, s1.Trip AS Trip1, s2.Trip AS Trip2
  FROM TimeShips s1, TimeShips s2
  WHERE s1.N = s2.N AND s1.MMSI < s2.MMSI AND CASE WHEN eDwithin(s1.Trip, s2.Trip, 300)
    THEN startValue(atMin(s1.Trip <-> s2.Trip)) < 300 END ),
Points AS (
  SELECT N, lonlat_pt(valueAtTimestamp(Trip1, T)) AS P1, lonlat_pt(valueAtTimestamp(Trip2, T)) AS P2
  FROM Pairs )
SELECT N,
  (SELECT COUNT(*) FROM TimeShips t WHERE t.N = p.N) AS ShipsInPeriod,
  (SELECT COUNT(*) * (COUNT(*) - 1) // 2 FROM TimeShips t WHERE t.N = p.N) AS DistinctPairs,
  COUNT(*) AS Answer,
  COUNT(*) FILTER (WHERE ST_X(P1) BETWEEN x0 AND x1 AND ST_Y(P1) BETWEEN y0 AND y1 AND
    ST_X(P2) BETWEEN x0 AND x1 AND ST_Y(P2) BETWEEN y0 AND y1) AS InEsbjergDetail
FROM Points p, Frame
GROUP BY N ORDER BY N;
