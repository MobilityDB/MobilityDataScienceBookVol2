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

-- The Hanoi numbers that chapter 7 prints, recomputed in MobilityDB over the loaded data.
\timing off
SELECT municipalityname, COUNT(*) AS intersectCount
FROM trips t, municipalities m
WHERE eintersects(t.trip, m.municipalitygeo)
GROUP BY municipalityname
ORDER BY intersectCount DESC LIMIT 6;
SELECT round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 0) AS TotalKm
FROM Trips t, Municipalities m
WHERE eintersects(t.trip, m.MunicipalityGeo);
WITH k AS (
  SELECT m.MunicipalityName, round((SUM(length(atGeometry(t.trip, m.MunicipalityGeo))) / 1000)::numeric, 0) AS km
  FROM Trips t, Municipalities m
  WHERE eintersects(t.trip, m.MunicipalityGeo)
  GROUP BY m.MunicipalityName)
(SELECT * FROM k ORDER BY km LIMIT 1) UNION ALL (SELECT * FROM k ORDER BY km DESC LIMIT 1);
SELECT COUNT(*) AS pairs FROM (
SELECT DISTINCT t1.VehicleId, t1.TripId, t2.VehicleId, t2.TripId
FROM (SELECT * FROM trips t1 ORDER BY TripId LIMIT 1000) t1,
  (SELECT * FROM trips t2 ORDER BY TripId LIMIT 1000) t2
WHERE t1.VehicleId < t2.VehicleId AND eDwithin(t1.Trip, t2.Trip, 10.0)) x;
