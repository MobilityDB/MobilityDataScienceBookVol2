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

-- Chapter 3: Temporal Geometries and Temporal Circular Buffers
-- Case study: underwater noise. The queries of the chapter, in its order, on the
-- AIS database of the book for January 20, 2026, after ships_noise.sql has added
-- the column Noise to the table Ships. The comment under each query is the answer
-- it gives.
\pset footer off
SET TimeZone = 'UTC';

-- The area affected by the noise of the fishing vessel during its trip
SELECT round(ST_Area(traversedArea(Noise, true)) / 1e6, 2) AS AreaKm2
FROM Ships
WHERE MMSI = 220323000;
-- 177.79

-- Evaluating the quietness of protected areas
SELECT aDwithin(n.Geom, v.Noise, 1000)
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 220323000 AND n.Id = 14;
-- f

SELECT eIntersects(n.Geom, v.Noise), eContains(n.Geom, v.Noise)
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 220323000 AND n.Id = 14;
-- t | f

SELECT eIntersects(n.Geom, v.Trip),
  duration(whenTrue(tIntersects(v.Noise, n.Geom))) AS NoiseInArea,
  duration(whenTrue(tDwithin(v.Noise, n.Geom, 1000))) AS Within1km
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 220323000 AND n.Id = 14;
-- f | 00:27:53.927402 | 00:36:48.886162

SELECT aIntersects(n.Geom, v.Noise)
FROM Ships v, NaturalAreas n
WHERE v.MMSI = 220323000 AND n.Id = 14;
-- f

-- The exposure of the protected areas over the day
CREATE TABLE Exposure AS
SELECT v.MMSI, n.Id AS AreaId,
  whenTrue(tIntersects(n.Geom, v.Noise)) AS Heard
FROM Ships v, NaturalAreas n
WHERE n.Realm <> 'Terrestrial' AND stbox(n.Geom) && stbox(v.Noise)
  AND eIntersects(n.Geom, v.Noise);
-- SELECT 3936

SELECT n.NameEng, COUNT(DISTINCT e.MMSI) AS Vessels,
  round(SUM(extract(epoch FROM duration(e.Heard))) / 3600, 1)
    AS VesselHours
FROM Exposure e JOIN NaturalAreas n ON n.Id = e.AreaId
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC LIMIT 3;
-- Skagens Gren og Skagerrak | 186 | 540.9
-- I | 147 | 263.0
-- W | 126 | 390.6

SELECT maxValue(tCount(Heard)) AS MaxVessels,
  startTimestamp(atMax(tCount(Heard))) AS AtTime
FROM Exposure WHERE AreaId = 122;
-- 27 | 2026-01-20 17:45:05.643419+00

WITH Heard AS (
  SELECT AreaId, spansetUnion(Heard) AS Heard
  FROM Exposure GROUP BY AreaId )
SELECT n.NameEng, round(1440 - extract(epoch FROM duration(h.Heard))
  / 60, 1) AS MinutesQuiet
FROM Heard h JOIN NaturalAreas n ON n.Id = h.AreaId
ORDER BY MinutesQuiet, n.NameEng LIMIT 3;
-- C | 0.0
-- Nordvestlige Kattegat | 0.0
-- Schultz og Hastens Grund samt Briseis Flak | 0.0

SELECT n.NameEng, COUNT(DISTINCT e.MMSI) AS Vessels
FROM Exposure e JOIN Ships v USING (MMSI)
  JOIN NaturalAreas n ON n.Id = e.AreaId
WHERE NOT eIntersects(v.Trip, n.Geom)
GROUP BY n.Id, n.NameEng
ORDER BY Vessels DESC, n.NameEng LIMIT 3;
-- Saltholm og omliggende hav | 96
-- Saltholm og omliggende hav | 96
-- Q | 94

-- Monitoring the distance between the moving regions of two vessels
CREATE OR REPLACE VIEW Fishing(Noise) AS
  SELECT Noise FROM Ships WHERE MMSI = 220323000;
CREATE OR REPLACE VIEW Passenger(Noise) AS
  SELECT Noise FROM Ships WHERE MMSI = 219000407;

SELECT numInstants(tDistance(a.Noise, b.Noise)),
  round(minValue(tDistance(a.Noise, b.Noise)), 2),
  round(maxValue(tDistance(a.Noise, b.Noise)), 2)
FROM Fishing a, Passenger b;
-- 1902 | 7735.04 | 53826.11

SELECT asText(nearestApproachInstant(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- Cbuffer(POINT(632718.9 6356807.66),2923.13)@2026-01-20 17:00:34+00

SELECT round(nearestApproachDistance(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- 7735.04

SELECT ST_AsText(shortestLine(a.Noise, b.Noise), 2)
FROM Fishing a, Passenger b;
-- LINESTRING(629809.54 6356524.29,622110.92 6355774.47)

-- Acoustic encounters
CREATE TABLE Encounter AS
SELECT a.MMSI AS MMSI1, b.MMSI AS MMSI2,
  whenTrue(tIntersects(a.Noise, b.Noise)) AS Overlap,
  nearestApproachDistance(a.Trip, b.Trip) AS TripDist
FROM Ships a, Ships b
WHERE a.MMSI < b.MMSI AND stbox(a.Noise) && stbox(b.Noise)
  AND eIntersects(a.Noise, b.Noise);
-- SELECT 30847

SELECT MMSI1, MMSI2, duration(Overlap) AS Overlap
FROM Encounter
WHERE TripDist > 5000
ORDER BY duration(Overlap) DESC LIMIT 1;
-- 273277840 | 319114200 | 20:45:27.579949
