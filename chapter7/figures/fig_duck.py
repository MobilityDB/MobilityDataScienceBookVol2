"""Figures of the DuckDB section of Chapter 7 (AIS, January 20, 2026), drawn with the Folium code
of the companion notebook chapter7/mobilityDuckAIS.ipynb (cells of Queries 6.6, 6.8, 6.9 and
6.10) over the OpenFreeMap vector basemap, from the CSV files written by duck_figdata.sql.
Each map has a fixed extent and pixel size."""
import sys
import pandas as pd
import folium
import matplotlib
import matplotlib.colors as mcolors
from shapely import wkt

from vtiles import VectorTiles
from vgprint import print_map, write_overlay
from vghybrid import print_map_hybrid


def shot(name, width, height, incl=None, labels=False, hide=(), hybrid=False, **overlay):
    """Print O + name.html to O + name.pdf at the CSS size of width x height
    device px at scale 2), with #print_map, or, when hybrid, with #print_map_hybrid of vghybrid.py (the
    basemap vector, the dense marker layer embedded as one lossless 300-dpi image); when incl (the
    \\includegraphics options of chapter7.tex) is given, write O + name_overlay.tex with the measured
    labels (labels=True) and the legend of `overlay`."""
    info = (print_map_hybrid if hybrid else print_map)(O + name + '.html', O + name + '.pdf',
                                                        round(width / 2), round(height / 2), hide=hide)
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
    shot('duckdbcentroid', 1278, 1032, hybrid=True)

if 'ships1000m' in which:
    gdf = pd.read_csv(D + 'ships1000m.csv')
    gdf['geometry'] = gdf['Geom'].apply(wkt.loads)
    m = folium.Map(location=[tgt.y, tgt.x], zoom_start=16, tiles=None)
    VectorTiles('positron').add_to(m)
    folium.CircleMarker(location=[tgt.y, tgt.x], radius=8, color='red', fill=True,
        fill_opacity=0.9).add_to(m)
    for _, row in gdf.iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=5,
            color='green', fill=True, fill_opacity=0.7).add_to(m)
    m.save(O + 'ships1000m.html')
    shot('ships1000m', 712, 534)

if 'count' in which:
    gdf = pd.read_csv(D + 'countships1000m.csv')
    gdf['geometry'] = gdf['Geom'].apply(wkt.loads)
    # the four classes of the legend: 0, 1-2, 3-5, 6+
    gdf['color'] = pd.cut(gdf['NeighborCount'], [-1, 0, 2, 5, 10**6],
        labels=['lightgray', 'yellow', 'orange', 'red']).astype(str)
    m = folium.Map(location=[55.95, 10.95], zoom_start=7, tiles=None)
    VectorTiles('positron').add_to(m)
    for _, row in gdf.sort_values('NeighborCount').iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=6,
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
    shot('countships1000m', 1388, 1056, incl='width=0.9\\textwidth', hybrid=True,
         hide=('div[style*="position: fixed"]',), legend_at='south west',
         legend=('Neighbor count', [(lab, mcolors.to_hex(c), 'dot') for lab, c in
                 [('0', 'lightgray'), ('1-2', 'yellow'), ('3-5', 'orange'), ('6+', 'red')]]))

if 'k5nn' in which:
    gdf = pd.read_csv(D + 'k5nn.csv')
    gdf['geometry'] = gdf['geom'].apply(wkt.loads)
    pts = list(gdf['geometry']) + [tgt]
    center = [(min(p.y for p in pts) + max(p.y for p in pts)) / 2,
              (min(p.x for p in pts) + max(p.x for p in pts)) / 2]
    # The map is laid out at the size it is printed (0.9\textwidth, 400 CSS px), at a zoom that shows
    # the harbour around the ships and keeps the six markers apart (the closest pair is 22 m apart)
    m = folium.Map(location=center, zoom_start=16, tiles=None)
    VectorTiles('positron').add_to(m)
    # The reference ship is a square, its neighbours are circles
    folium.RegularPolygonMarker(location=[tgt.y, tgt.x], number_of_sides=4, rotation=45, radius=7,
        color='red', weight=1, fill_color='red', fill_opacity=0.9, gradient=False).add_to(m)
    colors = ['blue', 'green', 'orange', 'purple', 'darkred']
    for idx, row in gdf.iterrows():
        folium.CircleMarker(location=[row.geometry.y, row.geometry.x], radius=4,
            color=colors[idx % len(colors)], weight=1, fill=True, fill_opacity=0.8).add_to(m)
    folium.Circle(location=[tgt.y, tgt.x], radius=1000, color='blue', fill=False, weight=2,
        opacity=0.5).add_to(m)
    m.save(O + 'k-5-NN.html')
    shot('k-5-NN', 800, 600, incl='width=0.9\\textwidth', legend_at='south west',
         legend=('Ships', [('Reference ship', mcolors.to_hex('red'), 'box')] +
                 [(f'Neighbour at {row.Distance:.0f} m', mcolors.to_hex(colors[idx % len(colors)]), 'dot')
                  for idx, row in gdf.iterrows()]))
