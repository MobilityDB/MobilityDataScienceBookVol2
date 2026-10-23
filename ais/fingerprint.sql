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

-- The fingerprints of AISClean and Segments that check_duckdb.sh compares with those of the
-- MobilityLakehouse pipeline: the number of rows and the MD5 of their keys, one line per row in
-- a total order. A report is keyed by its vessel, its instant in microseconds since 1970 and its
-- piece; a segment by its vessel, piece, type, first and last instants and number of reports.
--
--   psql -d ais -At -f fingerprint.sql

SELECT 'clean', COUNT(*), md5(string_agg(
  MMSI || ',' || (EXTRACT(EPOCH FROM T) * 1000000)::bigint || ',' || Piece, ';'
  ORDER BY MMSI, T))
FROM AISClean;

SELECT 'segments', COUNT(*), md5(string_agg(
  MMSI || ',' || Piece || ',' || SegmentType || ',' ||
  (EXTRACT(EPOCH FROM TStart) * 1000000)::bigint || ',' ||
  (EXTRACT(EPOCH FROM TEnd) * 1000000)::bigint || ',' || NoPoints, ';'
  ORDER BY MMSI, TStart, TEnd, SegmentType))
FROM Segments;
