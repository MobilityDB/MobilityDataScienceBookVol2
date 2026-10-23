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
-- Case study: underwater noise. The noise of the vessels of January 20, 2026, in the AIS
-- database of the book (ais/build.sh), as the column Noise of the table Ships: for each vessel
-- under way, the circle reached by its noise at 63 Hz, as a temporal circular buffer.
--
-- The source level of a report is the reference spectrum model of MacGillivray and de Jong
-- (ComputeSL, with the class speed of ComputeVc), from the class and the length of the vessel
-- in Vessels and the speed over ground of the report. The noise spreads spherically down to the
-- ambient level of 80 dB, so that its radius is 10^((SL - 80)/20) meters, capped at 10 km. The
-- model applies to a vessel under way: at the reports whose speed exceeds 3 knots (and is at
-- most 40 knots, above which a speed is an error), and outside the port areas.
--
-- Reads Ships, Vessels and AISClean of the AIS database, and Port of chapter5/load_aux_tables.sql;
-- creates the functions ComputeVc and ComputeSL and the tables VesselClass and PortAreas.
--
--   psql -d ais -f ships_noise.sql
\set ON_ERROR_STOP on
SET TimeZone = 'UTC';

-- -----------------------------------------------------------------------------
-- Return the reference class speed (Vc) based on vessel macro-category and
-- cargo classification.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ComputeVc;
CREATE FUNCTION ComputeVc(
  VesselClassCode  integer,
  ShipTypeCode     integer,
  SpeedKnots       double precision, 
  LOA              double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
  CASE
    WHEN VesselClassCode = 1  THEN 10.6
    WHEN VesselClassCode = 2  THEN 6.4
    WHEN VesselClassCode = 3  THEN 3.7
    WHEN VesselClassCode = 4  THEN 9.5
    WHEN VesselClassCode = 5  THEN 11.1
    WHEN VesselClassCode = 6  THEN 8.0
    WHEN VesselClassCode = 7  THEN       
      CASE WHEN (LOA > 100) THEN 17.1 ELSE 9.7 END
    WHEN VesselClassCode = 9  THEN
      CASE
        WHEN (ShipTypeCode = 70 OR ShipTypeCode BETWEEN 75 AND 79) AND
          SpeedKnots <= 16 THEN 13.9   -- Bulker
        ELSE 18.0   -- Containership
      END
    WHEN VesselClassCode = 10 THEN 12.4
    WHEN VesselClassCode = 11 THEN 7.4
    ELSE NULL
  END;
$$;


-- -----------------------------------------------------------------------------
-- Compute the Source Level (SL) following the model of
-- MacGillivray & de Jong for vessel underwater radiated noise.
--
-- Inputs:
--   VesselClassCode   : vessel macro-category
--   f                 : frequency (Hz)
--   Vref              : vessel speed (knots)
--   Vc                : reference class speed (knots)
--   LOAref            : vessel length overall (metres)
--   InPort            : whether the vessel is located inside a port
--
-- Output:
--   SL (dB re 1 µPa @ 1 m)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ComputeSL;
CREATE FUNCTION ComputeSL(
  VesselClassCode  integer,           -- 9 = cargo, 10 = tanker, 7 = cruise
  f                real,              -- frequency (Hz)
  Vref             double precision,  -- vessel speed (knots)
  Vc               double precision,  -- class reference speed (knots)
  LOAref           double precision,  -- vessel length (metres)
  InPort           boolean            -- whether the vessel is located inside a port
)
RETURNS DOUBLE PRECISION
LANGUAGE plpgsql
AS $$
DECLARE
  -- Vessel class flags
  isRecreational boolean :=        (VesselClassCode = 1);
  isFishing boolean :=             (VesselClassCode = 2);
  isTug boolean :=                 (VesselClassCode = 3);
  isDredger boolean :=             (VesselClassCode = 4);
  isNaval boolean :=               (VesselClassCode = 5);
  isGovernmentResearch boolean :=  (VesselClassCode = 6);
  isCruise boolean :=              (VesselClassCode = 7);
  isCargo boolean :=               (VesselClassCode = 9);
  isTanker boolean :=              (VesselClassCode = 10);
  isOther boolean :=               (VesselClassCode = 11);

  -- Model parameters
  K  DOUBLE PRECISION;
  B  DOUBLE PRECISION;
  f1 DOUBLE PRECISION;
  D  DOUBLE PRECISION;

  -- Intermediate terms of the analytical formulation
  term1 DOUBLE PRECISION;
  term2 DOUBLE PRECISION;
  term3 DOUBLE PRECISION;
  term4 DOUBLE PRECISION;
  term5 DOUBLE PRECISION;
  term6 DOUBLE PRECISION;

  SL DOUBLE PRECISION;

  -- Preserve the original speed for low-speed port correction
  Speed DOUBLE PRECISION := Vref;

BEGIN
  -- Parameter K
  IF f < 100 AND (isCargo OR isTanker) THEN K := 208;
  ELSE K := 191;
  END IF;

  -- Parameter B
  IF f < 100 AND (isCargo OR isTanker) THEN B := 2;
  ELSE B := 0;
  END IF;

  -- Characteristic frequency f1
  IF f < 100 AND (isCargo OR isTanker) THEN f1 := 600.0/Vc;
  ELSE f1 := 480.0/Vc;
  END IF;

  -- Parameter D
  IF f < 100 AND isCargo THEN D := 0.8;
  ELSIF f < 100 AND isTanker THEN D := 1.0;
  ELSIF isCruise THEN D := 4.0;
  ELSE D := 3.0;
  END IF;

  -- MacGillivray & de Jong source level formulation
  term1 := K - 10.0 * (B + 2.0) * LOG10(f1); 
  term2 :=  5.0 * B * LOG10(f);
  term3 := -10.0 * LOG10(POWER(1.0 - POWER(f/f1, 0.5*(B+2)), 2) + POWER(D,2));

  -- Enforce minimum modelling speed of 3 knots
  IF Vref < 3 THEN Vref:=3;
  END IF;

  term4 := 60.0 * LOG10(Vref / Vc);
  term5 := 20.0 * LOG10(LOAref / 91.44);  -- 91.44 m = reference LOA
  term6 := 10.0 * LOG10(0.231 * f);

  SL := term1 + term2 + term3 + term4 + term5 + term6;

  -- Empirical correction for vessels idling inside ports
  IF isCruise OR isCargo OR isTanker THEN
    IF InPort AND Speed < 0.5 THEN 
      SL := SL - 15;   -- subtract 15 dB
    END IF;
  END IF;

  RETURN SL;
END;
$$;


-- -----------------------------------------------------------------------------
-- The class of each vessel: its AIS ship type, the code of that type, and the vessel class of
-- the reference spectrum model, for the vessels whose type and length are known.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS VesselClass;
CREATE TABLE VesselClass AS
WITH Code AS (
  SELECT MMSI, ShipType, Length, CASE ShipType
    WHEN 'Pilot' THEN 50 WHEN 'SAR' THEN 51 WHEN 'Tug' THEN 52 WHEN 'Port tender' THEN 53
    WHEN 'Anti-pollution' THEN 54 WHEN 'Law enforcement' THEN 55 WHEN 'Fishing' THEN 30
    WHEN 'Towing' THEN 31 WHEN 'Towing long/wide' THEN 32 WHEN 'Dredging' THEN 33
    WHEN 'Diving' THEN 34 WHEN 'Military' THEN 35 WHEN 'Sailing' THEN 36 WHEN 'Pleasure' THEN 37
    WHEN 'HSC' THEN 40 WHEN 'Passenger' THEN 60 WHEN 'Cargo' THEN 70 WHEN 'Tanker' THEN 80
    WHEN 'Other' THEN 90 END AS ShipTypeCode
  FROM Vessels
  WHERE Length > 0 )
SELECT *, CASE ShipTypeCode
    WHEN 50 THEN 3 WHEN 51 THEN 6 WHEN 52 THEN 3 WHEN 53 THEN 3 WHEN 54 THEN 11 WHEN 55 THEN 6
    WHEN 30 THEN 2 WHEN 31 THEN 3 WHEN 32 THEN 3 WHEN 33 THEN 4 WHEN 34 THEN 11 WHEN 35 THEN 5
    WHEN 36 THEN 1 WHEN 37 THEN 1 WHEN 40 THEN 7 WHEN 60 THEN 7 WHEN 70 THEN 9 WHEN 80 THEN 10
    WHEN 90 THEN 11 END AS VesselClassCode
FROM Code WHERE ShipTypeCode IS NOT NULL;
ALTER TABLE VesselClass ADD PRIMARY KEY (MMSI);

DROP TABLE IF EXISTS PortAreas;
CREATE TABLE PortAreas AS
SELECT ST_Union(Geom) AS Geom FROM Port;

-- -----------------------------------------------------------------------------
-- The noise of each vessel under way: the radius at each report, as a temporal float split at
-- the silences of more than 600 seconds as the trips of Ships are, and the trip restricted to
-- the periods under way outside the port areas.
-- -----------------------------------------------------------------------------
ALTER TABLE Ships DROP COLUMN IF EXISTS Noise;
ALTER TABLE Ships ADD COLUMN Noise tcbuffer;
WITH Radius AS (
  SELECT a.MMSI, tfloatSeqSetGaps(array_agg(tfloat(least(10000,
    power(10, (ComputeSL(v.VesselClassCode, 63.0, a.SOG,
      ComputeVc(v.VesselClassCode, v.ShipTypeCode, a.SOG, v.Length),
      v.Length, false) - 80) / 20)), a.T) ORDER BY a.T),
    interval '600 s') AS Radius
  FROM AISClean a JOIN VesselClass v USING (MMSI)
  WHERE a.SOG > 3 AND a.SOG <= 40
  GROUP BY a.MMSI ),
Underway AS (
  SELECT r.MMSI, r.Radius,
    minusGeometry(atTime(s.Trip, getTime(r.Radius)), p.Geom) AS Trip
  FROM Radius r JOIN Ships s USING (MMSI), PortAreas p )
UPDATE Ships s
SET Noise = tcbuffer(u.Trip, atTime(u.Radius, getTime(u.Trip)))
FROM Underway u
WHERE s.MMSI = u.MMSI AND u.Trip IS NOT NULL;
-- UPDATE 1499
VACUUM ANALYZE Ships;

SELECT COUNT(*) AS Ships, COUNT(Noise) AS Noisy FROM Ships;
