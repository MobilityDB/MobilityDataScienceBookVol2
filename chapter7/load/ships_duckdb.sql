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

-- The listing "Table Creation, Population, and Indexing" of chapter 7, with {conn_str} the
-- PostgreSQL database ais, ${PG_AIS} and the extension the one of the MobilityDuck CI.
INSTALL spatial FROM core_nightly;
INSTALL postgres;
INSTALL '${MOBILITYDUCK_EXTENSION}';
LOAD spatial;
LOAD mobilityduck;
LOAD postgres;

CREATE OR REPLACE TABLE ships (MMSI integer, Trip tgeompoint, SOG tfloat,
  COG tfloat);

INSERT INTO ships
SELECT MMSI, Trip, SOG, COG
FROM postgres_scan('${PG_AIS}', 'public', 'ships');

SET threads=1;
SET memory_limit='7000MB';

SELECT COUNT(*) FROM ships;

ALTER TABLE ships ADD column trajectory geometry;
UPDATE ships set trajectory = trajectory(trip);
CREATE INDEX rtree_trip ON Ships USING RTREE(trajectory);
SELECT COUNT(*), COUNT(trajectory), SUM(numInstants(Trip)) FROM ships;
