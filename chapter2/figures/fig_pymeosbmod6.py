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

"""Figure pymeosbmod6_a/b of chapter 2: the streaming aggregation of the spatial extent of the
BerlinMOD trips in groups of 40, over the OpenFreeMap positron colours drawn as SVG by
Leaflet.VectorGrid (#VectorTiles in vtiles.py) and printed by #print_map of vgprint.py to a PDF
without images, as fig_pymeosbmod2_b.py does. The red frame is the extent of the whole dataset;
(a) draws the first 40 trips and their extent in blue; (b) adds the next 40 trips and the extent
after the 80 trips in green, which contains the blue one. The listing of the chapter draws (b);
(a) is the same listing stopped after the first group."""
import os
import sys
from pathlib import Path
import folium
import geopandas as gpd
import pandas as pd
import shapely.geometry as shp
from pymeos import *
from vtiles import VectorTiles
from vgprint import print_map
sys.path.append(str(Path(__file__).resolve().parents[2] / 'chapter7' / 'figures'))
from pdf_simplify import simplify_printed  # noqa: E402

HERE = Path(__file__).resolve().parent
D = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
pymeos_initialize()
trips = pd.read_csv(f'{D}/trips.csv', converters={'trip': TGeomPointSeq})

W_IN = round(0.48 * 332.89723 / 72.27, 4)  # inches: the subfigure is 0.48 of the text width
MARGIN = 1000                              # meters around the extent of the dataset


def draw(name, groups):
    # --- the listing printed in the chapter; (a) stops after the first group --------------
    total_extent = TemporalPointExtentAggregator.aggregate(trips["trip"])
    extent_aggregator = TemporalPointExtentAggregator.start_aggregation()
    m = folium.Map(tiles=None)
    VectorTiles("positron-city").add_to(m)
    extents = [(total_extent, "red")]
    for i, color in ((40, "blue"), (80, "green"))[:groups]:
        group = trips["trip"][i - 40:i]
        for trip in group:
            extent_aggregator.add(trip)
        gpd.GeoSeries(group.apply(lambda tr: tr.to_shapely_geometry()),
            crs=3857).explore(m=m, color=color, style_kwds={"weight": 1.5})
        extent = extent_aggregator.aggregation()
        extents.append((extent, color))
        print(f"{i} trips:", extent)
    for extent, color in extents:
        box = shp.box(extent.xmin(), extent.ymin(), extent.xmax(), extent.ymax())
        gpd.GeoSeries([box], crs=3857).explore(m=m, color=color,
            style_kwds={"fill": False, "weight": 2})
    # ------------------------------------------------------------------------------------------
    print('700 trips:', total_extent)
    b = gpd.GeoSeries([shp.box(total_extent.xmin(), total_extent.ymin(), total_extent.xmax(),
        total_extent.ymax()).buffer(MARGIN, join_style='mitre')], crs=3857).to_crs(4326).total_bounds
    css_w = 420
    css_h = round(css_w * (total_extent.ymax() - total_extent.ymin() + 2 * MARGIN) /
                  (total_extent.xmax() - total_extent.xmin() + 2 * MARGIN))
    html = f'{OUT}/{name}.html'
    m.save(html)
    print_map(html, f'{OUT}/{name}.pdf', css_w, css_h, W_IN, round(W_IN * css_h / css_w, 4),
              bounds=(b[1], b[0], b[3], b[2]))
    # below half a printed pixel, by #simplify_printed of chapter7/figures/pdf_simplify.py
    simplify_printed(f'{OUT}/{name}.pdf', W_IN * 25.4, squeezed=True)


draw('pymeosbmod6_a', 1)
draw('pymeosbmod6_b', 2)
