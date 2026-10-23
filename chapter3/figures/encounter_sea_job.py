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

"""Write the layers and the QGIS jobs of the figure fig:encounter_sea (ais_encounter_sea_a and
ais_encounter_sea_b), which storms_qgis_map.py renders: the longest acoustic encounter at sea of
the case study, the tanker TRIUMF (MMSI 273277840, in red) and the cargo vessel PUMA (MMSI
319114200, in blue) on January 20, 2026.

(a) The trajectories of the two vessels, with their positions at 4:00, 12:00 and 20:00 as dots
labelled with the time.
(b) The temporal circular buffers of their noise over the day, as their traversed areas filled
with a transparent color and a continuous outline, and their circular buffers at 4:00, 12:00 and
20:00 with a dashed outline and a dot at the center, as noise_region_job.py draws the noise of the
fishing vessel.

The two maps share one extent, the box of the two traversed areas with a margin of 5% above and
below and of 12% on the sides, where the times are written. The traversed area of a vessel is the
union of the pieces of traversedArea(Noise), linearized, which covers the same points as
traversedArea(Noise, true). The layers are GeoJSON files in EPSG:25832, the CRS of the table Ships, read from the AIS
database of the book after ships_noise.sql (the database named by the PostgreSQL environment
variables and by AIS_DB, default ais); the table EncounterFig holds the two vessels while the
script runs.

Usage: python3 encounter_sea_job.py <out>
"""
import json
import os
import subprocess
import sys

PSQL = ["psql", "-d", os.environ.get("AIS_DB", "ais"), "-X", "-At", "-v", "ON_ERROR_STOP=1"]
DPI = 300
WIDTH_PT, PAD, XPAD = 240, 0.05, 0.12
LAND, WATER = "#f2efe9", "#aad3df"
TIMES = ["2026-01-20 04:00:00+00", "2026-01-20 12:00:00+00", "2026-01-20 20:00:00+00"]
# The vessels with the line, fill and outline colors of each: red for TRIUMF and blue for PUMA
VESSELS = [(273277840, "255,0,0,255", "255,60,60,60", "255,0,0,255"),
           (319114200, "0,0,255,255", "60,90,255,60", "0,0,255,255")]


def query(sql):
    return subprocess.run(PSQL + ["-c", sql], check=True, capture_output=True,
                          text=True).stdout.strip()


def collection(path, expr, mmsi):
    """A GeoJSON file of the geometry expr of the vessel mmsi of EncounterFig, in EPSG:25832."""
    geom = query(f"SELECT ST_AsGeoJSON(({expr}), 2) FROM EncounterFig WHERE mmsi = {mmsi}")
    json.dump({"type": "FeatureCollection",
               "crs": {"type": "name", "properties": {"name": "urn:ogc:def:crs:EPSG::25832"}},
               "features": [{"type": "Feature", "properties": {}, "geometry": json.loads(geom)}]},
              open(path, "w"))


out = sys.argv[1]
query("DROP TABLE IF EXISTS EncounterFig; "
      "CREATE UNLOGGED TABLE EncounterFig AS "
      "SELECT MMSI, Trip, Noise, ST_UnaryUnion(ST_CurveToLine(traversedArea(Noise), 64)) "
      "AS trav "
      f"FROM Ships WHERE MMSI IN ({', '.join(str(v[0]) for v in VESSELS)})")
layers_a, layers_b, texts = [], [], []
for mmsi, line, fill, outline in VESSELS:
    collection(os.path.join(out, f"enc_trip_{mmsi}.geojson"), "trajectory(trip)", mmsi)
    collection(os.path.join(out, f"enc_trav_{mmsi}.geojson"), "trav", mmsi)
    times = "ARRAY['" + "','".join(TIMES) + "']::timestamptz[]"
    collection(os.path.join(out, f"enc_pos_{mmsi}.geojson"),
               f"ST_Collect(ARRAY(SELECT valueAtTimestamp(trip, t) FROM unnest({times}) t))", mmsi)
    collection(os.path.join(out, f"enc_circles_{mmsi}.geojson"),
               "ST_Collect(ARRAY(SELECT ST_CurveToLine(geometry(valueAtTimestamp(noise, t)), 64) "
               f"FROM unnest({times}) t))", mmsi)
    trip = {"path": f"enc_trip_{mmsi}.geojson", "kind": "line",
            "style": {"line_color": line, "line_width": "0.5"}}
    dots = {"path": f"enc_pos_{mmsi}.geojson", "kind": "marker",
            "style": {"name": "circle", "color": line, "outline_style": "no", "size": "1.6"}}
    layers_a += [trip, dots]
    layers_b += [{"path": f"enc_trav_{mmsi}.geojson", "kind": "fill",
                  "style": {"color": fill, "outline_color": outline, "outline_width": "0.35"}},
                 {"path": f"enc_circles_{mmsi}.geojson", "kind": "fill",
                  "style": {"color": "0,0,0,0", "outline_color": outline, "outline_width": "0.35",
                            "outline_style": "dash"}},
                 dots]
# The time of each position, written once beside the pair of positions, on the side where it
# meets no trajectory: to the left of the western one, to the right of the eastern one, or above
# the northern one
ANCHORS = {"left": "ST_X(p)", "right": "-ST_X(p)", "above": "-ST_Y(p)"}
for t, anchor in zip(TIMES, ["left", "right", "above"]):
    x, y = map(float, query(
        f"SELECT ST_X(p), ST_Y(p) FROM (SELECT valueAtTimestamp(trip, timestamptz '{t}') AS p "
        f"FROM EncounterFig) q ORDER BY {ANCHORS[anchor]} LIMIT 1").split("|"))
    texts.append({"x": x, "y": y, "text": f"{int(t[11:13])}:{t[14:16]}", "anchor": anchor,
                  "size": 12, "gap": 5})

x0, y0, x1, y1 = map(float, query(
    "SELECT ST_XMin(b), ST_YMin(b), ST_XMax(b), ST_YMax(b) FROM "
    "(SELECT ST_Extent(trav)::geometry AS b FROM EncounterFig) q").split("|"))
query("DROP TABLE EncounterFig")
dx, dy = (x1 - x0) * XPAD, (y1 - y0) * PAD
extent = [x0 - dx, x1 + dx, y0 - dy, y1 + dy]
w = round(WIDTH_PT / 72 * DPI)
size = [w, round(w * (extent[3] - extent[2]) / (extent[1] - extent[0]))]
base = {"type": "shortbread", "water": WATER, "streets": None, "buildings": None,
        "border": None, "water_min_area": 1e7, "water_lines": False}
for name, layers, txt in (("ais_encounter_sea_a", layers_a, texts),
                          ("ais_encounter_sea_b", layers_b, [])):
    spec = {"output": f"{name}.pdf", "crs": "EPSG:25832", "extent": extent, "size": size,
            "dpi": DPI, "land": LAND, "basemap_oversample": 2, "layers": [base] + layers,
            "texts": txt}
    json.dump(spec, open(os.path.join(out, f"{name}.json"), "w"), indent=1)
print("wrote", out, extent, size)
