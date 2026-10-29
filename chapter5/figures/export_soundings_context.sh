#!/bin/bash
#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

# The layers of the figure of the surveyed area off Rostock and the vessels of
# the day, into $OUT (default: the working directory), from the tables that
# ../../chapter3/soundings/load_soundings.sql adds to the AIS database of the
# book and from its table Ships: the area that the surveys cover, the trips of
# the survey vessel along the two lines, and the trips of the vessels of the
# day that came within 1 km of the area, cut to the extent of
# job_soundings_context.json. It follows ../../chapter3/figures/export_soundings.sh.
set -e
cd "${OUT:-$PWD}"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
export PGTZ=UTC
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt POLYGON soundings_area.gpkg "$PG" -nln area -overwrite -sql \
  "SELECT Geom AS geom FROM SurveyArea"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING soundings_trips.gpkg "$PG" -nln trips -overwrite -sql \
  "SELECT left(Line, 8) AS day, trajectory(Trip) AS geom FROM Tracks"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt MULTILINESTRING soundings_near.gpkg "$PG" -nln near -overwrite -sql \
  "SELECT s.MMSI, ST_Multi(ST_Intersection(trajectory(s.Trip),
     ST_MakeEnvelope(701450, 6007240, 704450, 6010240, 25832))) AS geom
   FROM Ships s, SurveyArea a
   WHERE eDwithin(s.Trip, a.Geom, 1000)"
for f in soundings_area soundings_trips soundings_near; do
  ogrinfo -so -al $f.gpkg | grep 'Feature Count'; done
