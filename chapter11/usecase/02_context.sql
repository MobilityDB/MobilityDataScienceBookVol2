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

-- Section "Computing and Rendering the Context" of the use case of chapter 11: the context of
-- every observed position of the windows, the attributes from which the descriptions of
-- 03_descriptions.sql are rendered. They are the attributes of the maritime enrichment of the
-- thesis (enrichment-pipeline/maritime/enrich/), computed from the tables of the AIS database
-- (Ships, AISClean, Vessels), of chapter 5 (Bathymetry, WaveHeight, NaturalAreas), and of
-- load_context.sh (WPIPort, SeaAreas, EEZ, TerritorialSea, TSS). The longitude and latitude of a
-- position come from the trip of the vessel in WGS 84, TripLonLat, so no geometry is transformed.
--
--   psql -d ais -f 02_context.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS PointContext CASCADE;
CREATE TABLE PointContext AS
SELECT p.GapId, p.PointIdx, p.T, g.MMSI, p.Geom,
  valueAtTimestamp(s.TripLonLat, p.T) AS GeomLonLat,
  valueAtTimestamp(s.SOG, p.T) AS SOG, valueAtTimestamp(s.COG, p.T) AS COG,
  valueAtTimestamp(s.Heading, p.T) AS Heading, valueAtTimestamp(s.ROT, p.T) AS ROT,
  r.NavigationalStatus, r.Draught, v.ShipType,
  ( SELECT ST_Value(b.Rast, p.Geom) FROM Bathymetry b
    WHERE ST_Intersects(b.Rast, p.Geom) LIMIT 1 ) AS Depth,
  ( SELECT ST_Value(w.Rast, p.Geom) FROM WaveHeight w
    WHERE w.ValidTime @> p.T AND ST_Intersects(w.Rast, p.Geom) LIMIT 1 ) AS Waves,
  o.Name AS PortName, o.Dist AS PortDist,
  ( SELECT a.Name FROM SeaAreas a WHERE ST_Intersects(a.Geom, p.Geom) LIMIT 1 ) AS SeaArea,
  ( SELECT e.Iso FROM EEZ e WHERE ST_Intersects(e.Geom, p.Geom) LIMIT 1 ) AS EEZ,
  EXISTS ( SELECT 1 FROM TerritorialSea t WHERE ST_Intersects(t.Geom, p.Geom) )
    AS TerritorialSea,
  ( SELECT t.Name FROM TSS t WHERE ST_Intersects(t.Geom, p.Geom) LIMIT 1 ) AS TSS,
  EXISTS ( SELECT 1 FROM TSS t WHERE ST_Intersects(t.Geom, p.Geom) ) AS InTSS,
  ( SELECT n.NameEng FROM NaturalAreas n WHERE ST_Intersects(n.Geom, p.Geom) LIMIT 1 )
    AS Protected,
  EXISTS ( SELECT 1 FROM NaturalAreas n WHERE ST_Intersects(n.Geom, p.Geom) ) AS InProtected
FROM TripPoints p JOIN Gaps g USING (GapId) JOIN Ships s USING (MMSI)
  LEFT JOIN Vessels v USING (MMSI)
  LEFT JOIN LATERAL (
    SELECT c.NavigationalStatus, c.Draught FROM AISClean c
    WHERE c.MMSI = g.MMSI AND c.T <= p.T
    ORDER BY c.T DESC LIMIT 1 ) r ON true
  LEFT JOIN LATERAL (
    SELECT w.Name, ST_Distance(w.Geom, p.Geom) AS Dist FROM WPIPort w
    ORDER BY w.Geom <-> p.Geom LIMIT 1 ) o ON true
WHERE NOT p.InGap;
ALTER TABLE PointContext ADD PRIMARY KEY (GapId, PointIdx);
ANALYZE PointContext;

SELECT COUNT(*) AS Positions, COUNT(SOG) AS WithSOG, COUNT(Heading) AS WithHeading,
  COUNT(Depth) AS WithDepth, COUNT(Waves) AS WithWaves, COUNT(SeaArea) AS WithSeaArea,
  COUNT(EEZ) AS WithEEZ, COUNT(*) FILTER (WHERE InTSS) AS InTSS,
  COUNT(*) FILTER (WHERE InProtected) AS InProtected
FROM PointContext;
