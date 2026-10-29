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

CREATE TABLE PoI (
  PoIId serial PRIMARY KEY,
  Name text NOT NULL,
  Geom geometry(Point, 4326) NOT NULL
);
INSERT INTO PoI VALUES
-- French Restaurant near Trip 1
(1, 'Le Meurice', ST_SetSRID(ST_Point(2.3281, 48.8655), 4326)),
-- Hotel used in many trips
(2, 'Hilton Paris Opera', ST_SetSRID(ST_Point(2.3364, 48.8530), 4326)),
-- Modern Art Museum near Trips 1-2-6
(3, 'Centre Pompidou', ST_SetSRID(ST_Point(2.3525, 48.8606), 4326)),
-- Italian Restaurant near Trip 1
(4, 'Pizza Chic', ST_SetSRID(ST_Point(2.3499, 48.8640), 4326)),         
-- Cinema near Trips 1-2-3
(5, 'Pathee Opera', ST_SetSRID(ST_Point(2.3520, 48.8565), 4326)),
-- Trip 4-7 Hotel
(6, 'Holiday Inn Paris Gare de l Est', ST_SetSRID(ST_Point(2.3550, 48.8560), 4326)),
-- Coffee shop near Trips 4-7
(7, 'Cafee de Flore', ST_SetSRID(ST_Point(2.3560, 48.8570), 4326)),
-- Attraction for Trip 6
(8, 'Eiffel Tower', ST_SetSRID(ST_Point(2.2945, 48.8584), 4326)),
-- Zoo for Trips 5 and 8
(9, 'Zoo de Vincennes', ST_SetSRID(ST_Point(2.3615, 48.8600), 4326)),
-- Italian cheap restaurant near Trip 9
(10, 'Le Petit Italien', ST_SetSRID(ST_Point(2.3490, 48.8590), 4326));