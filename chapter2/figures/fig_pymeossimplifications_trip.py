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

"""Figure pymeossimplifications-trip_a, _b and _c of chapter 2: the third trip of vehicle 34 on June 4,
2020, which runs east-west across Brussels, in green (a), its DP simplification in red (b) and its
SED simplification in blue (c), at the tolerance of 20 of the listing of the section Trajectory
Simplification, each a line through the instants it keeps, over the OpenFreeMap positron colours
drawn as SVG by Leaflet.VectorGrid (#VectorTiles in vtiles.py), printed by #print_map of vgprint.py
as fig_pymeosbmod2_b.py prints its map."""
import os
import sys
from pathlib import Path
import geopandas as gpd
import pandas as pd
from pymeos import *
from vtiles import VectorTiles
from vgprint import MM_PER_PX, print_map
sys.path.append(str(Path(__file__).resolve().parents[2] / 'chapter7' / 'figures'))
from pdf_simplify import simplify_printed  # noqa: E402

HERE = Path(__file__).resolve().parent
D = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
pymeos_initialize()
trips = pd.read_csv(f'{D}/trips.csv', converters={'trip': TGeomPointSeq})
tolerance = 20
simplifications = trips.copy()
simplifications["dp"] = simplifications["trip"].apply(
    lambda tr: tr.simplify_douglas_peucker(tolerance))
simplifications["sed"] = simplifications["trip"].apply(
    lambda tr: tr.simplify_douglas_peucker(tolerance, synchronized=True))

# --- the listing printed in the chapter -------------------------------------------------
from shapely.geometry import LineString, MultiPoint

trip = simplifications.iloc[495]
maps = {}
for key, color in (("trip", "green"), ("dp", "red"), ("sed", "blue")):
    points = [(p.x, p.y) for p in trip[key].values()]
    m = gpd.GeoSeries([LineString(points)], crs=3857).explore(
        tiles=None, color=color, style_kwds={"weight": 1.5})
    gpd.GeoSeries([MultiPoint(points)], crs=3857).explode(index_parts=False).explore(
        m=m, color=color, marker_kwds={"radius": 1.5},
        style_kwds={"fillOpacity": 1, "weight": 0})
    VectorTiles("positron-city").add_to(m)
    maps[key] = m
# ------------------------------------------------------------------------------------------

print(trip[["vehicle", "day", "seq"]].to_dict(), {k: trip[k].num_instants() for k in maps},
      {k: round(trip["trip"].distance(trip[k]).max_value(), 1) for k in ("dp", "sed")})

# The maps are laid out at the scale of zoom 12.149: a Web Mercator metre is 256 * 2^ZOOM / 40075016
# CSS px (40075016 m being the equator), of MM_PER_PX mm each, over the extent of the trip with a
# margin of 4% of its width and of its height plus 300 m
ZOOM = 12.149
b = trip["trip"].bounding_box()
dx, dy = (b.xmax() - b.xmin()) * 0.04, (b.ymax() - b.ymin()) * 0.04 + 300
px_per_m = 256 * 2 ** ZOOM / 40075016
css_w = round((b.xmax() - b.xmin() + 2 * dx) * px_per_m)
css_h = round((b.ymax() - b.ymin() + 2 * dy) * px_per_m)
width_mm, height_mm = css_w * MM_PER_PX, css_h * MM_PER_PX
ext = gpd.GeoSeries(gpd.points_from_xy([b.xmin() - dx, b.xmax() + dx], [b.ymin() - dy, b.ymax() + dy]),
                    crs=3857).to_crs(4326)
w, s, e, n = ext.total_bounds
for panel, key in zip("abc", maps):
    name = f'pymeossimplifications-trip_{panel}'
    html = f'{OUT}/{name}.html'
    maps[key].save(html)
    info = print_map(html, f'{OUT}/{name}.pdf', css_w, css_h, round(width_mm / 25.4, 4),
                     round(height_mm / 25.4, 4), bounds=(s, w, n, e))
    simplify_printed(f'{OUT}/{name}.pdf', width_mm, squeezed=True)
    print(name, round(width_mm, 1), 'x', round(height_mm, 1), 'mm zoom', round(info['zoom'], 3),
          'tiles', info['tiles'])
pymeos_finalize()
