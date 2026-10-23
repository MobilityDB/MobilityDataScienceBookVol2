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

"""Write the data layers and the QGIS job of a map figure of chapter 8, which qgis_map.py renders.

A job states the extent of the map in EPSG:3857, its size in pixels of 300 dpi of its printed
width, the Shortbread basemap of the book (land #f2efe9, water #aad3df, light streets, buildings
when asked) and the data layers, GeoJSON files in longitude and latitude, from bottom to top, as
the jobs of chapter5/figures (job_*.json) state theirs.
"""
import json
import os

from pyproj import Transformer

TO3857 = Transformer.from_crs(4326, 3857, always_xy=True)
DPI = 300
LAND, WATER = "#f2efe9", "#aad3df"


def extent3857(lon0, lon1, lat0, lat1):
    x0, y0 = TO3857.transform(lon0, lat0)
    x1, y1 = TO3857.transform(lon1, lat1)
    return x0, x1, y0, y1


def padded(xs, ys, pad):
    """The extent of the points xs, ys of EPSG:3857 with a margin of pad meters."""
    return min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad


def size(extent, width_in):
    """The pixels of 300 dpi of a map of the extent printed width_in inches wide."""
    x0, x1, y0, y1 = extent
    w = round(width_in * DPI)
    return w, round(w * (y1 - y0) / (x1 - x0))


def rgba(c):
    """The color [r, g, b] or [r, g, b, a] (0-255) as QGIS reads it from a field."""
    return ",".join(str(int(v)) for v in (list(c) + [255])[:4])


def points(path, lons, lats, colors=None):
    """A GeoJSON file of points, with their color in the field color when given."""
    feats = []
    for i, (lon, lat) in enumerate(zip(lons, lats)):
        props = {"color": colors[i]} if colors is not None else {}
        feats.append({"type": "Feature", "properties": props,
                      "geometry": {"type": "Point", "coordinates": [float(lon), float(lat)]}})
    json.dump({"type": "FeatureCollection", "features": feats}, open(path, "w"))


def geometry(path, geom):
    """A GeoJSON file of one geometry (a GeoJSON geometry dictionary)."""
    json.dump({"type": "FeatureCollection", "features": [
        {"type": "Feature", "properties": {}, "geometry": geom}]}, open(path, "w"))


def job(out, name, extent, width_in, layers, streets="#ffffff", buildings=None, border=None):
    """Write <out>/<name>.json, the job of the map <name>.pdf."""
    base = {"type": "shortbread", "water": WATER, "streets": streets, "buildings": buildings,
            "border": border, "streets_width": 0.12}
    spec = {"output": f"{name}.pdf", "extent": list(extent), "size": list(size(extent, width_in)),
            "dpi": DPI, "land": LAND, "layers": [base] + layers}
    json.dump(spec, open(os.path.join(out, f"{name}.json"), "w"), indent=1)
    return spec
