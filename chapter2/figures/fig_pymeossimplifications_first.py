"""Figure pymeossimplifications-first_a and _b of chapter 2: the first BerlinMOD trip, in grey, under
its DP simplification in red (a) and its SED simplification in blue (b), each drawn as a line through
the instants it keeps, over the OpenFreeMap positron colours drawn as SVG by Leaflet.VectorGrid
(#VectorTiles in vtiles.py), printed by #print_map of vgprint.py as fig_pymeosbmod2_b.py prints its
map. The simplifications are those of the listing of the section Trajectory Simplification."""
import os
import sys
from pathlib import Path
import geopandas as gpd
import pandas as pd
from shapely.geometry import LineString, MultiPoint
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
first = trips["trip"].iloc[0]
simplified = {"a": (first.simplify_douglas_peucker(tolerance), "red"),
              "b": (first.simplify_douglas_peucker(tolerance, synchronized=True), "blue")}
print('instants', first.num_instants(), {k: v[0].num_instants() for k, v in simplified.items()})

# Each panel is laid out at its printed size, 0.48 of the text width by 0.36 (\includegraphics of
# chapter2.tex), in mm / MM_PER_PX, the scale of the maps of fig_delhi.py, over the extent of the trip
TEXTWIDTH_MM = 332.89723 / 72.27 * 25.4
width_mm, height_mm = 0.48 * TEXTWIDTH_MM, 0.36 * TEXTWIDTH_MM
css_w = round(width_mm / MM_PER_PX)
css_h = round(height_mm / MM_PER_PX)
trip = gpd.GeoSeries([LineString([(p.x, p.y) for p in first.values()])], crs=3857)
w, s, e, n = trip.to_crs(4326).total_bounds
dx, dy = (e - w) * 0.04, (n - s) * 0.04
for panel, (simple, color) in simplified.items():
    points = [(p.x, p.y) for p in simple.values()]
    m = trip.explore(tiles=None, color="gray", style_kwds={"weight": 6, "opacity": 0.6})
    gpd.GeoSeries([LineString(points)], crs=3857).explore(
        m=m, color=color, style_kwds={"weight": 1.5})
    gpd.GeoSeries([MultiPoint(points)], crs=3857).explode(index_parts=False).explore(
        m=m, color=color, marker_kwds={"radius": 2}, style_kwds={"fillOpacity": 1, "weight": 0})
    VectorTiles("positron-city").add_to(m)
    name = f'pymeossimplifications-first_{panel}'
    html = f'{OUT}/{name}.html'
    m.save(html)
    info = print_map(html, f'{OUT}/{name}.pdf', css_w, css_h, round(width_mm / 25.4, 4),
                     round(height_mm / 25.4, 4), bounds=(s - dy, w - dx, n + dy, e + dx))
    simplify_printed(f'{OUT}/{name}.pdf', width_mm)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
pymeos_finalize()
