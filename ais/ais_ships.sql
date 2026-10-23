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

-- The tables Vessels and Ships, built from AISClean.
--
-- Vessels holds one row per vessel with its static attributes, each the value it reports most
-- often over the period, ties broken by the smallest value.
--
-- Ships holds one row per vessel with its trajectory over the period, in EPSG:25832 in Trip and
-- in longitude and latitude in TripLonLat, and the speed over ground (knots), course over ground
-- (degrees), heading (degrees) and rate of turn (degrees per minute) it reports, as temporal
-- floats. The speed is interpolated linearly between two reports; the course and the heading are
-- angles, which a linear interpolation from 359 to 1 degree would sweep through 180 degrees, so
-- they and the rate of turn use step interpolation, keeping a reported value until the next. Every
-- temporal value has a gap wherever the vessel is silent for more than 600 s, the rule that cuts
-- AISClean into pieces. A speed over ground of 102.3 kn is the code AIS uses for a speed that is
-- not available, and is left out of SOG; the Danish Maritime Authority leaves an unavailable
-- heading or rate of turn empty.
--
--   psql -d ais -f ais_ships.sql

\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

DROP TABLE IF EXISTS Vessels CASCADE;
CREATE TABLE Vessels AS
SELECT MMSI,
  mode() WITHIN GROUP (ORDER BY Name COLLATE "C") AS Name,
  mode() WITHIN GROUP (ORDER BY IMO COLLATE "C") AS IMO,
  mode() WITHIN GROUP (ORDER BY CallSign COLLATE "C") AS CallSign,
  mode() WITHIN GROUP (ORDER BY ShipType COLLATE "C") AS ShipType,
  mode() WITHIN GROUP (ORDER BY CargoType COLLATE "C") AS CargoType,
  mode() WITHIN GROUP (ORDER BY Length) AS Length,
  mode() WITHIN GROUP (ORDER BY Width) AS Width,
  mode() WITHIN GROUP (ORDER BY Draught) AS Draught,
  mode() WITHIN GROUP (ORDER BY SizeA) AS SizeA,
  mode() WITHIN GROUP (ORDER BY SizeB) AS SizeB,
  mode() WITHIN GROUP (ORDER BY SizeC) AS SizeC,
  mode() WITHIN GROUP (ORDER BY SizeD) AS SizeD
FROM AISClean
GROUP BY MMSI;
ALTER TABLE Vessels ADD PRIMARY KEY (MMSI);

DROP TABLE IF EXISTS Ships CASCADE;
CREATE TABLE Ships AS
SELECT MMSI,
  tgeompointSeqSetGaps(array_agg(tgeompoint(Geom, T) ORDER BY T), interval '600 s') AS Trip,
  tgeompointSeqSetGaps(
    array_agg(tgeompoint(ST_Point(Longitude, Latitude, 4326), T) ORDER BY T),
    interval '600 s') AS TripLonLat,
  tfloatSeqSetGaps(array_agg(tfloat(SOG, T) ORDER BY T) FILTER (WHERE SOG < 102.3),
    interval '600 s') AS SOG,
  tfloatSeqSetGaps(array_agg(tfloat(COG, T) ORDER BY T) FILTER (WHERE COG IS NOT NULL),
    interval '600 s', NULL, 'step') AS COG,
  tfloatSeqSetGaps(array_agg(tfloat(Heading, T) ORDER BY T) FILTER (WHERE Heading IS NOT NULL),
    interval '600 s', NULL, 'step') AS Heading,
  tfloatSeqSetGaps(array_agg(tfloat(ROT, T) ORDER BY T) FILTER (WHERE ROT IS NOT NULL),
    interval '600 s', NULL, 'step') AS ROT
FROM AISClean
GROUP BY MMSI;
ALTER TABLE Ships ADD PRIMARY KEY (MMSI);

SELECT COUNT(*) AS Ships, COUNT(SOG) AS WithSOG, COUNT(COG) AS WithCOG,
  COUNT(Heading) AS WithHeading, COUNT(ROT) AS WithROT,
  SUM(numSequences(Trip)) AS Pieces
FROM Ships;
