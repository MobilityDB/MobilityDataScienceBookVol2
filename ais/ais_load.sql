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

-- The table AISInput: the position reports of the Danish Maritime Authority with the 26 columns
-- of its CSV files, unchanged. MMSI is bigint and text columns are unbounded, so a single
-- malformed value cannot abort the load. build.sh appends one CSV file per day with
--
--   unzip -p aisdk-2026-01-20.zip | PGOPTIONS='-c datestyle=ISO,DMY' psql -d ais -c "\copy
--     AISInput FROM STDIN CSV HEADER"
--
--   psql -d ais -f ais_load.sql

\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

DROP TABLE IF EXISTS AISInput CASCADE;
CREATE TABLE AISInput(
  T timestamp,
  TypeOfMobile text,
  MMSI bigint,
  Latitude float,
  Longitude float,
  NavigationalStatus text,
  ROT float,
  SOG float,
  COG float,
  Heading integer,
  IMO text,
  CallSign text,
  Name text,
  ShipType text,
  CargoType text,
  Width float,
  Length float,
  TypeOfPositionFixingDevice text,
  Draught float,
  Destination text,
  ETA text,
  DataSourceType text,
  SizeA float,
  SizeB float,
  SizeC float,
  SizeD float
);
