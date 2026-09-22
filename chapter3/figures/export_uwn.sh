#!/bin/bash
# Export the layers of the two case-study figures of the tcbuffer chapter from
# the database loaded by the MobilityDB-Tcbuffer loader on one day of DMA AIS
# (2025-01-01): the fishing vessel MMSI 219013538 (trip 1) with its traversed
# area and the protected areas around it, and the passenger vessel MMSI
# 219000407 (trip 1) with the temporal distance between the two noise regions.
set -e
cd "${OUT:-$PWD}"
PG="PG:${PGCONN:-dbname=tcbuffer}"
export PGTZ=UTC
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt MULTILINESTRING -overwrite traj.gpkg "$PG" -nln traj -sql \
  "SELECT MMSI::text AS mmsi, ST_Multi(Trajectory) AS geom FROM VesselTrip
   WHERE (MMSI, TripId) IN ((219013538, 1), (219000407, 1))"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt MULTIPOLYGON -overwrite noise.gpkg "$PG" -nln noise -sql \
  "SELECT MMSI::text AS mmsi, ST_Multi(ST_CurveToLine(traversedArea(Noise, true))) AS geom FROM VesselTrip
   WHERE (MMSI, TripId) IN ((219013538, 1), (219000407, 1))"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt MULTIPOLYGON -overwrite areas.gpkg "$PG" -nln areas -sql \
  "SELECT n.Id AS id, n.NameEng AS name, ST_Multi(n.Geom) AS geom
   FROM NaturalAreas n, VesselTrip v
   WHERE (v.MMSI, v.TripId) = (219013538, 1) AND ST_DWithin(n.Geom, v.TraversedArea, 15000)"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING -overwrite shortest.gpkg "$PG" -nln shortest -sql \
  "SELECT shortestLine(a.Noise, b.Noise) AS geom
   FROM VesselTrip a, VesselTrip b
   WHERE (a.MMSI, a.TripId) = (219013538, 1) AND (b.MMSI, b.TripId) = (219000407, 1)"
ogr2ogr -f GPKG -a_srs EPSG:25832 -nlt LINESTRING -overwrite samples.gpkg "$PG" -nln samples -sql \
  "SELECT to_char(t, 'HH24:MI') AS label,
     shortestLine(atTime(a.Noise, t), atTime(b.Noise, t)) AS geom
   FROM VesselTrip a, VesselTrip b,
     generate_series(timestamptz '2025-01-01 02:00+00', '2025-01-01 22:00+00', interval '2 hours') t
   WHERE (a.MMSI, a.TripId) = (219013538, 1) AND (b.MMSI, b.TripId) = (219000407, 1)
     AND atTime(a.Noise, t) IS NOT NULL AND atTime(b.Noise, t) IS NOT NULL"
for f in traj noise areas shortest samples; do echo "$f $(ogrinfo -so $f.gpkg $f | grep 'Feature Count')"; done
psql -X -At -c \
  "SELECT ST_XMin(b), ST_YMin(b), ST_XMax(b), ST_YMax(b) FROM (SELECT ST_Extent(TraversedArea) AS b
   FROM VesselTrip WHERE (MMSI, TripId) = (219013538, 1)) t" \
  -c "SELECT ST_XMin(b), ST_YMin(b), ST_XMax(b), ST_YMax(b) FROM (SELECT ST_Extent(TraversedArea) AS b
   FROM VesselTrip WHERE (MMSI, TripId) IN ((219013538, 1), (219000407, 1))) t"
