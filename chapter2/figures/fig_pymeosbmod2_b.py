"""Figure pymeosbmod2_b of chapter 2: the Brussels communes and the 700 BerlinMOD trips over the
OpenFreeMap positron colours drawn as SVG by Leaflet.VectorGrid (#VectorTiles in vtiles.py),
printed by #print_map of vgprint.py to a PDF without images, fitted to the extent of the data."""
import os
import sys
from functools import partial
from pathlib import Path
import geopandas as gpd
import pandas as pd
from shapely import wkb
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
communes = pd.read_csv(f'{D}/brussels_communes.csv', converters={'geom': partial(wkb.loads, hex=True)})
communes['color'] = ['#00ff00', '#ff00ff', '#007fff', '#ff7f00', '#7fbf7f', '#47139e', '#ad0414',
    '#d981f9', '#138014', '#f4fc2c', '#00ffff', '#00ff7f', '#c04d7c', '#85eaf3', '#85d601',
    '#fca880', '#0000ff', '#019d92', '#907817']
communes = gpd.GeoDataFrame(communes, geometry='geom')

# --- the listing printed in the chapter -------------------------------------------------
communes = communes.set_crs(3857)
m = communes.explore(color=communes["color"], tiles=None, tooltip="name",
    style_kwds={"color": "#1f77b4", "weight": 1, "fillOpacity": 0.1})
trajectories = gpd.GeoSeries(trips["trip"].apply(lambda tr: tr.to_shapely_geometry()), crs=3857)
trajectories.explore(m=m, color="blue", style_kwds={"weight": 1})
VectorTiles("positron-city").add_to(m)
# ------------------------------------------------------------------------------------------

# The map is laid out at its printed size, 5.6 cm high (\includegraphics of chapter2.tex) with the
# shape w x h, in mm / MM_PER_PX, the scale of the maps of fig_delhi.py, fitted to the extent of the
# data, and simplified below half a printed pixel by #simplify_printed of
# chapter7/figures/pdf_simplify.py
w, h = 653, 678                         # the shape of the figure
height_mm = 56
width_mm = height_mm * w / h
css_w = round(width_mm / MM_PER_PX)
css_h = round(css_w * h / w)
b = gpd.GeoSeries(list(trajectories) + list(communes.geometry), crs=3857).to_crs(4326).total_bounds
html = f'{OUT}/pymeosbmod2_b.html'
m.save(html)
info = print_map(html, f'{OUT}/pymeosbmod2_b.pdf', css_w, css_h, round(width_mm / 25.4, 4),
                 round(height_mm / 25.4, 4), bounds=(b[1], b[0], b[3], b[2]))
simplify_printed(f'{OUT}/pymeosbmod2_b.pdf', width_mm, squeezed=True)
print('bounds', b, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
pymeos_finalize()
