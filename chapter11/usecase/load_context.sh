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

# Load the reference layers downloaded by fetch_context.sh into the AIS database of the book
# (the database named by PGDATABASE, PGHOST, ...), each transformed once to EPSG:25832:
#   SeaAreas(Name, Geom)             IHO sea areas
#   EEZ(Name, Iso, Geom)             exclusive economic zones; Iso is the ISO 3166 code of the
#                                    territory
#   TerritorialSea(Name, Iso, Geom)  12 nautical mile territorial seas
#   TSS(Name, Geom)                  traffic separation zones
#   WPIPort(Name, Geom)              ports of the World Port Index around the study area
# Every layer is clipped to the study area with a margin of one degree before it is transformed,
# since the WFS service also returns polygons that cross the antimeridian, which EPSG:25832 cannot
# represent; the polygons of each clipped geometry are kept. The layers are read with ogr2ogr through a PG connection string, as
# chapter5/build_aux_data.sh reads the ports and protected areas.
#
#   bash load_context.sh
set -e
DATA=${DATA:-$PWD/data}
D="$DATA/context"
PSQL="psql -X -q -v ON_ERROR_STOP=1"
PG="PG:dbname=${PGDATABASE:-$USER}${PGHOST:+ host=$PGHOST}${PGPORT:+ port=$PGPORT}${PGUSER:+ user=$PGUSER}"
OGR="-overwrite -spat 2 52 17 60 -clipsrc 2 52 17 60 -t_srs EPSG:25832 -nlt GEOMETRY
  -lco GEOMETRY_NAME=geom -lco FID=fid"

ogr2ogr -f PostgreSQL "$PG" "$D/iho.geojson" -nln SeaAreasLoad $OGR
ogr2ogr -f PostgreSQL "$PG" "$D/eez.geojson" -nln EEZLoad $OGR
ogr2ogr -f PostgreSQL "$PG" "$D/eez_12nm.geojson" -nln TerritorialSeaLoad $OGR
ogr2ogr -f PostgreSQL "$PG" "$D/tss.geojson" -nln TSSLoad $OGR

$PSQL <<'EOF'
CREATE TEMP TABLE StudyArea AS
SELECT ST_Transform(ST_MakeEnvelope(3, 53, 16, 59, 4326), 25832) AS Geom;

DROP TABLE IF EXISTS SeaAreas, EEZ, TerritorialSea, TSS, WPIPort;
CREATE TABLE SeaAreas AS
SELECT l.name AS Name, ST_Multi(ST_CollectionExtract(l.geom, 3)) AS Geom FROM SeaAreasLoad l, StudyArea a
WHERE ST_Intersects(l.geom, a.Geom);
CREATE TABLE EEZ AS
SELECT l.geoname AS Name, l.iso_ter1 AS Iso, ST_Multi(ST_CollectionExtract(l.geom, 3)) AS Geom
FROM EEZLoad l, StudyArea a
WHERE ST_Intersects(l.geom, a.Geom);
CREATE TABLE TerritorialSea AS
SELECT l.geoname AS Name, l.iso_ter1 AS Iso, ST_Multi(ST_CollectionExtract(l.geom, 3)) AS Geom
FROM TerritorialSeaLoad l, StudyArea a
WHERE ST_Intersects(l.geom, a.Geom);
CREATE TABLE TSS AS
SELECT l.name AS Name, ST_Multi(ST_CollectionExtract(l.geom, 3)) AS Geom FROM TSSLoad l;
DROP TABLE SeaAreasLoad, EEZLoad, TerritorialSeaLoad, TSSLoad;

CREATE TABLE WPIPortLoad(Name text, Lat float, Lon float);
EOF
python3 - "$D/wpi.csv" <<'EOF' | $PSQL -c "\copy WPIPortLoad FROM STDIN CSV"
import csv, sys
w = csv.writer(sys.stdout)
for r in csv.DictReader(open(sys.argv[1], encoding='utf-8-sig')):
    w.writerow([r['Main Port Name'], r['Latitude'], r['Longitude']])
EOF
$PSQL <<'EOF'
CREATE TABLE WPIPort AS
SELECT Name, ST_Transform(ST_Point(Lon, Lat, 4326), 25832) AS Geom
FROM WPIPortLoad
WHERE Lon BETWEEN 2 AND 17 AND Lat BETWEEN 52 AND 60;
DROP TABLE WPIPortLoad;

CREATE INDEX ON SeaAreas USING gist (Geom);
CREATE INDEX ON EEZ USING gist (Geom);
CREATE INDEX ON TerritorialSea USING gist (Geom);
CREATE INDEX ON TSS USING gist (Geom);
CREATE INDEX ON WPIPort USING gist (Geom);
ANALYZE SeaAreas, EEZ, TerritorialSea, TSS, WPIPort;

SELECT 'SeaAreas' AS Layer, count(*) FROM SeaAreas
UNION ALL SELECT 'EEZ', count(*) FROM EEZ
UNION ALL SELECT 'TerritorialSea', count(*) FROM TerritorialSea
UNION ALL SELECT 'TSS', count(*) FROM TSS
UNION ALL SELECT 'WPIPort', count(*) FROM WPIPort;
EOF
