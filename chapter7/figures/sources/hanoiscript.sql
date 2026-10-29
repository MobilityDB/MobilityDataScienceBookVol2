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

-- Query 1. Trips that crosses the largest number of districts.
WITH tripInt AS
 (SELECT vehicleid, tripid,
         COUNT(DISTINCT m.municipalityid) AS intersectCount
  FROM trips t, municipalities m
  WHERE eintersects(trip, municipalitygeo)
GROUP BY vehicleid, tripid)
SELECT t1.*, ST_AsText(t.trajectory) AS trajectory
FROM trips t JOIN tripInt t1 ON (t.tripId = t1.tripId AND t.vehicleid = t1.vehicleid)
ORDER BY intersectCount DESC
LIMIT 1;

-- Query 2. Total distance traveled per minicipality.
SELECT m.MunicipalityName,
  round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 3)
    AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo)
GROUP BY m.MunicipalityName;
