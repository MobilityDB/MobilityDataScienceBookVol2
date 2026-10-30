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

-- The fingerprint of Ships, the table of trips that the chapters query: the number of vessels, of
-- their instants and of their sequences, and the MD5 of their keys, one line per vessel ordered by
-- MMSI. A vessel is keyed by its MMSI, the number of instants and of sequences of its trip, and
-- its first and last instants in microseconds since 1970. The trips depend on the MobilityDB that
-- ais_ships.sql builds them with, which keeps an instant exactly when it is not redundant, so the
-- README states the fingerprint of the MobilityDB it was built with.
--
--   psql -d ais -At -f ships_fingerprint.sql

SELECT 'ships', COUNT(*), SUM(numInstants(Trip)), SUM(numSequences(Trip)), md5(string_agg(
  MMSI || ',' || numInstants(Trip) || ',' || numSequences(Trip) || ',' ||
  (EXTRACT(EPOCH FROM startTimestamp(Trip)) * 1000000)::bigint || ',' ||
  (EXTRACT(EPOCH FROM endTimestamp(Trip)) * 1000000)::bigint, ';' ORDER BY MMSI))
FROM Ships;
