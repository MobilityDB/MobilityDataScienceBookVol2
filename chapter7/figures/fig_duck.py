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

"""Figures of the DuckDB section of Chapter 7 (AIS, January 20, 2026), drawn with the Folium code
of the companion notebook chapter7/mobilityDuckAIS.ipynb (cells of Queries 6.6, 6.8, 6.9 and
6.10) over the OpenFreeMap vector basemap, from the CSV files written by duck_figdata.sql.
Each map has a fixed extent and pixel size."""
import math
import sys
import pandas as pd
import folium
import matplotlib
import matplotlib.colors as mcolors
from shapely import wkt

from vtiles import VectorTiles
from vgprint import print_map, write_overlay
from vghybrid import print_map_hybrid, print_dpi, TEXTWIDTH_MM
from pdf_simplify import simplify_printed


def shot(name, width, height, incl=None, labels=False, hide=(), printed=None, hybrid=False,
         bounds=None, shown=None, **overlay):
    """Print O + name.html to O + name.pdf at the CSS size of width x height
    device px at scale 2), with #print_map, or, when hybrid, with #print_map_hybrid of vghybrid.py (the
    basemap vector, the dense marker layer embedded as one lossless image of the printed pixels at
    300 dpi), with the extent bounds (south, west, north, east) when given, as #save of fig_hanoi.py
    does; when printed (the fraction of \\textwidth at which the book prints the map) is given,
    the paths of the map are simplified below half a printed pixel by #simplify_printed of
    pdf_simplify.py, and when shown is also given the page is widened by white margins so that the
    map shows at that fraction of \\textwidth; when incl (the
    \\includegraphics options of chapter7.tex) is given, write O + name_overlay.tex with the measured
    labels (labels=True) and the legend of `overlay`."""
    if hybrid:
        info = print_map_hybrid(O + name + '.html', O + name + '.pdf', round(width / 2), round(height / 2),
                                hide=hide, dpi=print_dpi(round(width / 2), printed))
    else:
        info = print_map(O + name + '.html', O + name + '.pdf', round(width / 2), round(height / 2),
                         hide=hide, bounds=bounds)
    if printed:
        simplify_printed(O + name + '.pdf', (shown or printed) * TEXTWIDTH_MM)
    if shown:
        import pikepdf
        with pikepdf.open(O + name + '.pdf', allow_overwriting_input=True) as p:
            x0, y0, x1, y1 = [float(v) for v in p.pages[0].mediabox]
            pad = (x1 - x0) * (printed / shown - 1) / 2
            p.pages[0].mediabox = [x0 - pad, y0, x1 + pad, y1]
            p.save(O + name + '.pdf')
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'], 'labels',
          [lb['text'] for lb in info['labels']])
    if incl:
        write_overlay(O + name + '_overlay.tex', f'figs/chap7/{name}.pdf', incl,
                      'ov' + ''.join(c for c in name if c.isalpha()),
                      labels=info['labels'] if labels else (), comment=sys.argv[0].split('/')[-1],
                      **overlay)

D = 'data/ais/'
O = 'out/'
which = sys.argv[1:] or ['centroid', 'ships1000m', 'count', 'k5nn']
tgt = wkt.loads(pd.read_csv(D + 'target.csv')['Geom'].iloc[0])
# The two maps of the ships around the ship in red share the size of the map and the printed size of
# the dots of the centroids map (498 CSS px shown at 0.7\textwidth); each has the extent its ships
# read best at: the whole port of Skagen with its breakwaters (750 m west, 1,480 m east, 780 m south,
# 770 m north of the ship in red) for the ships within 1 km, its inner harbour (560 m west and east,
# 380 m south, 600 m north) for the five nearest neighbours
_kx, _ky = 1 / (111320 * math.cos(math.radians(tgt.y))), 1 / 110574
SKAGEN = (tgt.y - 780 * _ky, tgt.x - 750 * _kx, tgt.y + 770 * _ky, tgt.x + 1480 * _kx)
INNER_HARBOUR = (tgt.y - 380 * _ky, tgt.x - 560 * _kx, tgt.y + 600 * _ky, tgt.x + 560 * _kx)

if 'centroid' in which:
    gdf = pd.read_csv(D + 'centroids.csv')
    gdf['geometry'] = gdf['centroid_wkt'].apply(lambda s: wkt.loads(s) if isinstance(s, str) else None)
    gdf = gdf[gdf['geometry'].notnull()]
    m = folium.Map(location=[57.07, 10.66], zoom_start=8, tiles=None)
    VectorTiles('positron').add_to(m)
    unique_mmsi = gdf['MMSI'].unique()
    cmap = matplotlib.colormaps['tab20'].resampled(len(unique_mmsi))
    mmsi_to_color = {mmsi: mcolors.to_hex(cmap(i)) for i, mmsi in enumerate(unique_mmsi)}
    gdf['color'] = gdf['MMSI'].map(mmsi_to_color)
    for _, row in gdf.iterrows():
        if row.geometry.is_empty:
            continue
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=2,
            color=row['color'], fill=True, fill_opacity=0.7).add_to(m)
    m.save(O + 'duckdbcentroid.html')
    shot('duckdbcentroid', 1278, 1032, printed=0.9, hybrid=True)

if 'ships1000m' in which:
    gdf = pd.read_csv(D + 'ships1000m.csv')
    gdf['geometry'] = gdf['Geom'].apply(wkt.loads)
    m = folium.Map(location=[tgt.y, tgt.x], zoom_start=14, tiles=None)
    VectorTiles('positron').add_to(m)
    for _, row in gdf.iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=2,
            color='green', fill=True, fill_opacity=0.7).add_to(m)
    folium.CircleMarker(location=[tgt.y, tgt.x], radius=3, color='red', fill=True,
        fill_opacity=0.9).add_to(m)
    m.save(O + 'ships1000m.html')
    # chapter7.tex prints the page at 0.9\textwidth, so the page has white margins on both sides
    shot('ships1000m', 996, 696, printed=0.9, shown=0.7, bounds=SKAGEN)

if 'count' in which:
    gdf = pd.read_csv(D + 'countships1000m.csv')
    gdf['geometry'] = gdf['Geom'].apply(wkt.loads)
    # the four classes of the legend: 0, 1-2, 3-5, 6+
    gdf['color'] = pd.cut(gdf['NeighborCount'], [-1, 0, 2, 5, 10**6],
        labels=['lightgray', 'yellow', 'orange', 'red']).astype(str)
    m = folium.Map(location=[55.95, 10.95], zoom_start=7, tiles=None)
    VectorTiles('positron').add_to(m)
    for _, row in gdf.sort_values('NeighborCount').iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=2,
            color=row['color'], fill=True, fill_color=row['color'], fill_opacity=0.8).add_to(m)
    legend_html = """
    <div style="position: fixed; bottom: 45px; left: 3px; width: 155px; z-index: 9999;
      background-color: white; border: 2px solid grey; font-size: 13px; padding: 8px;">
    <b>Neighbor count</b><br>
    <span style="background: lightgray; display: inline-block; width: 12px; height: 12px;"></span> 0<br>
    <span style="background: yellow; display: inline-block; width: 12px; height: 12px;"></span> 1-2<br>
    <span style="background: orange; display: inline-block; width: 12px; height: 12px;"></span> 3-5<br>
    <span style="background: red; display: inline-block; width: 12px; height: 12px;"></span> 6+
    </div>"""
    m.get_root().html.add_child(folium.Element(legend_html))
    m.save(O + 'countships1000m.html')
    shot('countships1000m', 1388, 1056, incl='width=0.9\\textwidth', printed=0.9, hybrid=True,
         hide=('div[style*="position: fixed"]',), legend_at='south west',
         legend=('Neighbor count', [(lab, mcolors.to_hex(c), 'dot') for lab, c in
                 [('0', 'lightgray'), ('1-2', 'yellow'), ('3-5', 'orange'), ('6+', 'red')]]))

if 'k5nn' in which:
    gdf = pd.read_csv(D + 'k5nn.csv')
    gdf['geometry'] = gdf['geom'].apply(wkt.loads)
    pts = list(gdf['geometry']) + [tgt]
    center = [(min(p.y for p in pts) + max(p.y for p in pts)) / 2,
              (min(p.x for p in pts) + max(p.x for p in pts)) / 2]
    # The map has the size and the markers of the map of the ships within 1 km
    m = folium.Map(location=center, zoom_start=16, tiles=None)
    VectorTiles('positron').add_to(m)
    # The reference ship is a square, its neighbours are circles
    colors = ['blue', 'green', 'orange', 'purple', 'darkred']
    for idx, row in gdf.iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=2,
            color=colors[idx % len(colors)], fill=True, fill_opacity=0.8).add_to(m)
    folium.RegularPolygonMarker(location=[tgt.y, tgt.x], number_of_sides=4, rotation=45, radius=5,
        color='red', weight=1, fill_color='red', fill_opacity=0.9, gradient=False).add_to(m)
    folium.Circle(location=[tgt.y, tgt.x], radius=1000, color='blue', fill=False, weight=2,
        opacity=0.5).add_to(m)
    m.save(O + 'k-5-NN.html')
    shot('k-5-NN', 996, 696, incl='width=0.7\\textwidth', printed=0.7, bounds=INNER_HARBOUR,
         legend_at='south west',
         legend=('Ships', [('Reference ship', mcolors.to_hex('red'), 'box')] +
                 [(f'Neighbour at {row.Distance:.0f} m', mcolors.to_hex(colors[idx % len(colors)]), 'dot')
                  for idx, row in gdf.iterrows()]))
