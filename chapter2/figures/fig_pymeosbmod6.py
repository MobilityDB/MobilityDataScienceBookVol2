"""Figure pymeosbmod6_a/b of chapter 2: the streaming aggregation of the spatial extent of the
BerlinMOD trips in groups of 40, over the OpenFreeMap positron colours drawn as SVG by
Leaflet.VectorGrid (#VectorTiles in vtiles.py) and printed by #print_map of vgprint.py to a PDF
without images, as fig_pymeosbmod2_b.py does. The red frame is the extent of the whole dataset;
(a) draws the first 40 trips and their extent in blue; (b) adds the next 40 trips and the extent
after the 80 trips in green, which contains the blue one. The listing of the chapter draws (b);
(a) is the same listing stopped after the first group."""
import os
from pathlib import Path
import folium
import geopandas as gpd
import pandas as pd
import shapely.geometry as shp
from pymeos import *
from vtiles import VectorTiles
from vgprint import print_map

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
    VectorTiles("positron").add_to(m)
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
            style_kwds={"fill": False, "weight": 3})
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


draw('pymeosbmod6_a', 1)
draw('pymeosbmod6_b', 2)
