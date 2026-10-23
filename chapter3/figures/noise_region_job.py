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

"""Write the layers and the QGIS job of the figure ais_noise_region (fig:temporalregions), which
storms_qgis_map.py renders: the noise region of the fishing vessel SLESVIG (MMSI 220323000)
leaving the harbor of Osterby on January 20, 2026, between 4:30 and 5:30, as the whole temporal
circular buffer of that hour (its traversed area, with a continuous outline) and, over it, its
circular buffers at 4:30, 4:45, 5:00, 5:15 and 5:30 in blue with a dashed outline, each with a dot
at its center and its time written beside it, with the trajectory in blue.

The extent is the box of the region with a margin of 8% and the aspect 1.6 of the printed figure.
The layers are GeoJSON files in EPSG:25832, the CRS of the table Ships, read from the AIS database
of the book after ships_noise.sql (the database named by the PostgreSQL environment variables and
by AIS_DB, default ais).

Usage: python3 noise_region_job.py <out>
"""
import json
import os
import subprocess
import sys

PSQL = ["psql", "-d", os.environ.get("AIS_DB", "ais"), "-X", "-At"]
DPI = 300
WIDTH_PT, ASPECT, PAD = 432, 1.6, 0.08
LAND, WATER = "#f2efe9", "#aad3df"
TIMES = ["2026-01-20 04:30:00+00", "2026-01-20 04:45:00+00", "2026-01-20 05:00:00+00",
         "2026-01-20 05:15:00+00", "2026-01-20 05:30:00+00"]
# Where the time of each instant is written: beside the circle in the harbor, and above the
# circles at sea
ANCHORS = ["left", "above", "above", "above", "above"]
# The hour of the figure: the temporal circular buffer, the trip and the traversed area
HOUR = ("(SELECT cb, tr, traversedArea(cb, true) AS trav FROM (SELECT "
        "atTime(Noise, tstzspan '[2026-01-20 04:30:00+00, 2026-01-20 05:30:00+00]') AS cb, "
        "atTime(Trip, tstzspan '[2026-01-20 04:30:00+00, 2026-01-20 05:30:00+00]') AS tr "
        "FROM Ships WHERE MMSI = 220323000) q) AS hour")


def query(sql):
    return subprocess.run(PSQL + ["-c", sql], check=True, capture_output=True,
                          text=True).stdout.strip()


def collection(path, sql):
    """A GeoJSON file of the geometry that sql returns, in EPSG:25832."""
    geom = query(f"SELECT ST_AsGeoJSON(({sql}), 2) FROM {HOUR}")
    json.dump({"type": "FeatureCollection",
               "crs": {"type": "name", "properties": {"name": "urn:ogc:def:crs:EPSG::25832"}},
               "features": [{"type": "Feature", "properties": {}, "geometry": json.loads(geom)}]},
              open(path, "w"))


out = sys.argv[1]
collection(os.path.join(out, "noise_tcbuffer.geojson"), "ST_CurveToLine(trav, 64)")
collection(os.path.join(out, "noise_track.geojson"), "trajectory(tr)")
layers = [
    {"path": "noise_tcbuffer.geojson", "kind": "fill",
     "style": {"color": "60,90,255,50", "outline_color": "0,0,200,255",
               "outline_width": "0.4"}},
    {"path": "noise_track.geojson", "kind": "line",
     "style": {"line_color": "0,0,255,255", "line_width": "0.5"}},
]
texts = []
for k, (t, anchor) in enumerate(zip(TIMES, ANCHORS)):
    name = f"noise_{k}.geojson"
    collection(os.path.join(out, name),
               f"ST_CurveToLine(geometry(valueAtTimestamp(cb, timestamptz '{t}')), 64)")
    layers.append({"path": name, "kind": "fill",
                   "style": {"color": "60,90,255,70", "outline_color": "0,0,160,255",
                             "outline_width": "0.4", "outline_style": "dash"}})
    # The label of the instant: above the top of the circle, or beside its center
    cx, cy, r = map(float, query(
        f"SELECT ST_X(point(c)), ST_Y(point(c)), radius(c) FROM "
        f"(SELECT valueAtTimestamp(cb, timestamptz '{t}') AS c FROM {HOUR}) q").split("|"))
    label = f"{int(t[11:13])}:{t[14:16]}"
    texts.append({"x": cx, "y": cy + r if anchor == "above" else cy, "text": label,
                  "anchor": anchor, "size": 11.5, "gap": 3 if anchor == "above" else 9})
# The center of each circle, the position of the vessel at the instant
collection(os.path.join(out, "noise_centers.geojson"),
           "ST_Collect(ARRAY(SELECT point(valueAtTimestamp(cb, t)) FROM unnest(ARRAY['"
           + "','".join(TIMES) + "']::timestamptz[]) AS t))")
layers.append({"path": "noise_centers.geojson", "kind": "marker",
               "style": {"name": "circle", "color": "0,0,255,255", "outline_style": "no",
                         "size": "1.3"}})

# The box of the region with a margin, widened to the aspect of the printed figure
x0, y0, x1, y1 = map(float, query(
    "SELECT ST_XMin(b), ST_YMin(b), ST_XMax(b), ST_YMax(b) FROM "
    f"(SELECT ST_Extent(ST_CurveToLine(trav, 64))::geometry AS b FROM {HOUR}) q").split("|"))
w, h = (x1 - x0) * (1 + 2 * PAD), (y1 - y0) * (1 + 2 * PAD)
w, h = max(w, h * ASPECT), max(h, w / ASPECT)
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
extent = [cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2]
size = [round(WIDTH_PT / 72 * DPI), round(WIDTH_PT / 72 * DPI / ASPECT)]
base = {"type": "shortbread", "water": WATER, "streets": "#ffffff", "buildings": None,
        "border": None}
spec = {"output": "ais_noise_region.pdf", "crs": "EPSG:25832", "extent": extent, "size": size,
        "dpi": DPI, "land": LAND, "layers": [base] + layers, "texts": texts}
json.dump(spec, open(os.path.join(out, "ais_noise_region.json"), "w"), indent=1)
print("wrote", out, extent, size)
