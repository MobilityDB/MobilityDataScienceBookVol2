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

-- Point Clouds: the values of the schema 1 of the multibeam soundings, which
-- load_soundings.sql states, built from their coordinates.
SET TimeZone = 'UTC';
SET client_min_messages = warning;
\pset footer off

\echo == Listing: the dimensions of a sounding
SELECT getX(p), getY(p), getZ(p), getDim(p, 'Amplitude') AS Amplitude,
  getDim(p, 'Beam') AS Beam
FROM (SELECT pcpoint(1, ARRAY[702995, 6008577, -5.06, 3636, 256]::float[]) AS p) t;

\echo == Listing: a temporal patch of two pings
SELECT numInstants(v) AS Pings, numPoints(v) AS Soundings, interp(v) AS Interp,
  asText(tgeometry(v)) AS Positions
FROM (SELECT tpcpatchSeq(ARRAY[
  tpcpatch(pcpatch(1, ARRAY[702995, 6008577, -5.06, 3636, 255,
    702996, 6008577, -5.08, 3512, 256]::float[]), timestamptz '2019-10-22 08:54:50.80'),
  tpcpatch(pcpatch(1, ARRAY[702995, 6008578, -5.05, 3701, 255]::float[]),
    timestamptz '2019-10-22 08:54:50.84')], 'discrete') AS v) t;
