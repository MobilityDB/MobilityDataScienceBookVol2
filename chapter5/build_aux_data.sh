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

# Build the ports and the protected areas of the case study, data/port.csv and
# data/natural_areas.csv.gz, from the files fetched by `fetch_data.sh aux`, in
# the format read by load_aux_tables.sql and by the loader of chapter 3.
#
# - Ports: the 139 Danish ports of GISCO ports 2013 (Eurostat), and four
#   terminals listed in aux/extra_ports.csv, each as a buffer of 1000 m around
#   its position in EPSG:25832. aux/gisco_ports_traffic.csv gives the name of
#   each GISCO port in the Eurostat list of reporting ports and whether it
#   reports traffic; no query of the book reads these two columns.
# - Protected areas: the 283 areas of the World Database on Protected Areas
#   (WDPA) of Denmark whose identifiers are listed, with the identifier the
#   book uses, in aux/natural_areas_sites.csv, transformed to EPSG:25832.
#
# The files are staged in the schema aux_stage of the database named by the
# PostgreSQL environment variables, which needs PostGIS, and removed afterwards.
# The WDPA may not be redistributed: the output stays in data/.
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
# The WDPA release is the one fetch_data.sh downloaded (the most recent one in data/aux when
# several are), or the one WDPA_RELEASE names (e.g. Sep2026). Protected Planet publishes a
# release as shapefiles (WDPA_<release>_DNK_shp.zip) or as a file geodatabase
# (WDPA_<release>_DNK_gdb.zip); both are read.
if [ -n "$WDPA_RELEASE" ]; then
  WDPA_ZIP=$(ls "$DATA"/aux/WDPA_${WDPA_RELEASE}_DNK_{shp,gdb}.zip 2> /dev/null | head -1)
else
  WDPA_ZIP=$(ls -t "$DATA"/aux/WDPA_*_DNK_{shp,gdb}.zip 2> /dev/null | head -1)
fi
[ -s "$WDPA_ZIP" ] || { echo "no WDPA archive in $DATA/aux: run fetch_data.sh aux" >&2; exit 1; }
R=$(basename "$WDPA_ZIP" | cut -d_ -f2)
PSQL="psql -X -q -v ON_ERROR_STOP=1"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
W=$DATA/aux/work
rm -rf "$W"; mkdir -p "$W"

unzip -q -o "$DATA/aux/PORT_2013_SH.zip" -d "$W"
unzip -q -o "$WDPA_ZIP" -d "$W/wdpa"
for z in "$W"/wdpa/*_shp_[0-9].zip; do
  [ -f "$z" ] && unzip -q -o "$z" -d "${z%.zip}"
done

$PSQL -c "DROP SCHEMA IF EXISTS aux_stage CASCADE; CREATE SCHEMA aux_stage;"
ogr2ogr -f PostgreSQL "$PG" "$W/PORT_2013_SH/Data/PORT_PT_2013.shp" \
  -nln aux_stage.port_pt -lco GEOMETRY_NAME=geom
ogr2ogr -f PostgreSQL "$PG" "$W/PORT_2013_SH/Data/PORT_AT_2013.dbf" -nln aux_stage.port_at
first=1
for s in "$W"/wdpa/*_shp_[0-9]/*-polygons.shp; do
  [ -f "$s" ] || continue
  if [ $first = 1 ]; then mode=""; first=0; else mode="-append"; fi
  ogr2ogr -f PostgreSQL "$PG" "$s" -nln aux_stage.wdpa -nlt MULTIPOLYGON \
    -lco GEOMETRY_NAME=geom $mode
done
for g in "$W"/wdpa/*.gdb; do
  [ -d "$g" ] || continue
  layer=$(ogrinfo -q "$g" | sed -n 's/^Layer: \(WDPA_WDOECM_poly_[^ ]*\).*/\1/p')
  ogr2ogr -f PostgreSQL "$PG" "$g" "$layer" -nln aux_stage.wdpa -nlt MULTIPOLYGON \
    -lco GEOMETRY_NAME=geom
done

$PSQL <<EOF
SET search_path = aux_stage, public;
CREATE TABLE sites (id integer, site_id integer);
\copy sites FROM '$HERE/aux/natural_areas_sites.csv' CSV HEADER
CREATE TABLE traffic (port_id text, rep_mar_l text, traffic integer);
\copy traffic FROM '$HERE/aux/gisco_ports_traffic.csv' CSV HEADER
CREATE TABLE extra (id integer, port_id text, data_src_c text, port_coor_ text,
  cntr_code text, port_name text, rep_mar_l text, source text, traffic integer,
  x float8, y float8);
\copy extra FROM '$HERE/aux/extra_ports.csv' CSV HEADER

DO \$\$
DECLARE missing integer;
BEGIN
  SELECT count(*) INTO missing FROM sites s
  WHERE NOT EXISTS (SELECT 1 FROM wdpa w WHERE w.site_id = s.site_id);
  IF missing > 0 THEN
    RAISE EXCEPTION '% protected areas of the book are absent from the WDPA release', missing;
  END IF;
END \$\$;

CREATE TABLE port AS
WITH p AS (
  SELECT pt.port_id, pt.data_src_c::text, pt.port_coor_, at.cntr_code, at.port_name,
    t.rep_mar_l, 'GISCO' AS source, t.traffic,
    ST_Buffer(ST_Transform(pt.geom, 25832), 1000) AS geom
  FROM port_pt pt JOIN port_at at USING (port_id) JOIN traffic t USING (port_id)
  UNION ALL
  SELECT port_id, data_src_c, port_coor_, cntr_code, port_name, rep_mar_l, source,
    traffic, ST_Buffer(ST_SetSRID(ST_Point(x, y), 25832), 1000)
  FROM extra )
SELECT row_number() OVER (ORDER BY port_id) AS id, * FROM p;

CREATE TABLE natural_areas AS
SELECT s.id, w.site_id, w.site_pid, w.site_type, w.name_eng, w.name, w.desig,
  w.desig_eng, w.desig_type, w.iucn_cat, w.int_crit, w.realm, w.rep_m_area,
  w.gis_m_area, w.rep_area, w.gis_area, w.no_take, w.no_tk_area, w.status,
  w.status_yr, w.gov_type, w.govsubtype, w.own_type, w.ownsubtype, w.mang_auth,
  w.mang_plan, w.verif, w.metadataid, w.prnt_iso3, w.iso3, w.supp_info,
  w.cons_obj, w.inlnd_wtrs, w.oecm_asmt,
  ST_AsText(ST_Multi(ST_Transform(w.geom, 25832))) AS geom
FROM sites s JOIN wdpa w USING (site_id);

-- The geometries of the book: aux/natural_areas_geom.csv holds the area, the perimeter, and
-- the number of vertices in EPSG:25832 of each area of the release of September 2026, measures
-- that do not depend on the order of the vertices and parts, which a release may change. The
-- areas of the release read whose area differs by more than 1 m2, perimeter by more than 1 cm,
-- or number of vertices are listed; the answers of the book that read them may then differ.
CREATE TABLE geom_check (id integer, site_id integer, area_m2 numeric, perimeter_m numeric,
  npoints integer);
\copy geom_check FROM '$HERE/aux/natural_areas_geom.csv' CSV HEADER
SELECT n.id, n.site_id, n.name_eng, g.area_m2 AS BookArea,
  round(ST_Area(ST_GeomFromText(n.geom))::numeric, 1) AS ReleaseArea,
  g.npoints AS BookPoints, ST_NPoints(ST_GeomFromText(n.geom)) AS ReleasePoints
FROM natural_areas n JOIN geom_check g USING (id)
WHERE abs(ST_Area(ST_GeomFromText(n.geom)) - g.area_m2) > 1
  OR abs(ST_Perimeter(ST_GeomFromText(n.geom)) - g.perimeter_m) > 0.01
  OR ST_NPoints(ST_GeomFromText(n.geom)) <> g.npoints
ORDER BY n.id;

SELECT (SELECT count(*) FROM port) AS Ports, (SELECT count(*) FROM natural_areas) AS Areas;
\copy (SELECT * FROM port ORDER BY id) TO '$DATA/port.csv' CSV HEADER
\copy (SELECT * FROM natural_areas ORDER BY id) TO PROGRAM 'gzip -c > $DATA/natural_areas.csv.gz' CSV HEADER
DROP SCHEMA aux_stage CASCADE;
EOF
rm -rf "$W"
echo "wrote $DATA/port.csv and $DATA/natural_areas.csv.gz (WDPA release $R)"
