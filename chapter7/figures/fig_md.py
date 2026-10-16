"""Figures of the MobilityDuck AIS section of Chapter 7 (January 20, 2026), drawn with the Folium code
of the companion notebook chapter7/mobilityDuckAIS.ipynb (cells of Queries 6.18 to 6.23) over the
OpenFreeMap vector basemap, from the CSV files written by md_figdata.sql, whose geometries are
already in longitude and latitude. Each map has a fixed pixel size;
its extent fits the results."""
import sys
import pandas as pd
import folium
import matplotlib
import matplotlib.colors as mcolors
from shapely import wkt
from shapely.geometry import LineString, MultiLineString, GeometryCollection

from vtiles import VectorTiles
from vgprint import print_map, write_overlay


def shot(name, width, height, incl=None, labels=False, hide=(), places=(), **overlay):
    """Print O + name.html to O + name.pdf at the CSS size of width x height
    device px at scale 2), with #print_map; when incl (the \\includegraphics options of chapter7.tex) is
    given, write O + name_overlay.tex with the measured labels (labels=True), or the places alone
    (labels='places'), and the legend of `overlay`."""
    info = print_map(O + name + '.html', O + name + '.pdf', round(width / 2), round(height / 2),
                     hide=hide, places=places)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'], 'labels',
          [lb['text'] for lb in info['labels']])
    if incl:
        write_overlay(O + name + '_overlay.tex', f'figs/chap7/{name}.pdf', incl,
                      'ov' + ''.join(c for c in name if c.isalpha()),
                      labels=([lb for lb in info['labels'] if lb.get('place')] if labels == 'places' else
                              info['labels'] if labels else ()), comment=sys.argv[0].split('/')[-1],
                      **overlay)

D = 'data/ais/'
O = 'out/'
which = sys.argv[1:] or ['rodbyputt', 'belt', 'points_a', 'points_b', 'close_a', 'close_b',
                         'copenh', 'copenhstop']


def lines_of(geom):
    """The polylines of a trajectory, as `#add_traj` of the notebook (cell of Query 6.21) splits
    a LineString or MultiLineString; the parts of a GeometryCollection, which a trajectory with
    isolated instants yields, are split the same way and its points are left out."""
    if isinstance(geom, LineString):
        return [geom]
    if isinstance(geom, (MultiLineString, GeometryCollection)):
        return [l for g in geom.geoms for l in lines_of(g)]
    return []


def latlon(line):
    """Folium (latitude, longitude) pairs of a line, as `#add_traj` builds its locations."""
    return [(pt[1], pt[0]) for pt in line.coords]


if 'rodbyputt' in which:
    trajs = pd.read_csv(D + 'rodbyputt.csv')
    trajs['geom_obj'] = trajs['Trajectory'].apply(wkt.loads)
    m = folium.Map(location=[54.575, 11.29], zoom_start=12, tiles=None)
    VectorTiles('positron').add_to(m)
    cmap = matplotlib.colormaps['tab10']
    for i, row in trajs.iterrows():
        for line in lines_of(row['geom_obj']):
            folium.PolyLine(locations=latlon(line), color=mcolors.to_hex(cmap(i)), weight=1.5,
                opacity=0.8, tooltip=f"MMSI: {row['MMSI']}").add_to(m)
    for name, col in [('Rodby', 'Rodby'), ('Puttgarden', 'Puttgarden')]:
        port = wkt.loads(trajs[col].iloc[0])
        minx, miny, maxx, maxy = port.bounds
        folium.Rectangle(bounds=[[miny, minx], [maxy, maxx]], color='blue', weight=2,
            fill=False).add_to(m)
        folium.Marker(location=[miny, maxx], icon=folium.DivIcon(
            html=f'<div style="font-size:9px; color:blue">{name}</div>')).add_to(m)
    pr = [wkt.loads(trajs[c].iloc[0]).bounds for c in ('Rodby', 'Puttgarden')]
    m.fit_bounds([[min(b[1] for b in pr), min(b[0] for b in pr)],
                  [max(b[3] for b in pr), max(b[2] for b in pr)]])
    m.save(O + 'rodbyputt.html')
    shot('rodbyputt', 580, 810, incl='width=0.6\\textwidth', labels=True)

if 'belt' in which:
    trajs = pd.read_csv(D + 'belt.csv')
    trajs['geom_obj'] = trajs['traj'].apply(wkt.loads)
    belt = wkt.loads(trajs['belt'].iloc[0])
    minx, miny, maxx, maxy = belt.bounds
    m = folium.Map(location=[(miny + maxy) / 2, (minx + maxx) / 2], zoom_start=12, tiles=None)
    VectorTiles('liberty').add_to(m)
    folium.Polygon(locations=latlon(belt.exterior), color='blue', weight=2, fill=True,
        fill_color='blue', fill_opacity=0.1, tooltip='Belt').add_to(m)
    for _, row in trajs.iterrows():
        for line in lines_of(row['geom_obj']):
            folium.PolyLine(locations=latlon(line), color='crimson', weight=1, opacity=0.7,
                tooltip=f"MMSI: {row['MMSI']}").add_to(m)
    m.fit_bounds([[miny, minx], [maxy, maxx]])
    m.save(O + 'belt.html')
    shot('belt', 448, 432)

for fig, loc, zoom, size in [('points_a', None, None, (724, 856)),
                             ('points_b', [55.4742, 8.4235], 16, (732, 862))]:
    if fig not in which:
        continue
    df = pd.read_csv(D + 'pointsclose300.csv')
    df['p1'] = df['Point1'].map(wkt.loads)
    df['p2'] = df['Point2'].map(wkt.loads)
    if loc is None:
        loc = [(df['p1'].map(lambda p: p.y).mean() + df['p2'].map(lambda p: p.y).mean()) / 2,
               (df['p1'].map(lambda p: p.x).mean() + df['p2'].map(lambda p: p.x).mean()) / 2]
        zoom = 7
    m = folium.Map(location=loc, zoom_start=zoom, tiles=None)
    VectorTiles('positron').add_to(m)
    if fig == 'points_a':
        xs = list(df['p1'].map(lambda p: p.x)) + list(df['p2'].map(lambda p: p.x))
        ys = list(df['p1'].map(lambda p: p.y)) + list(df['p2'].map(lambda p: p.y))
        m.fit_bounds([[min(ys), min(xs)], [max(ys), max(xs)]])
    for _, row in df.iterrows():
        p1, p2 = row['p1'], row['p2']
        folium.CircleMarker(location=[p1.y, p1.x], radius=4, color='red', fill=True,
            fill_opacity=0.9).add_to(m)
        folium.CircleMarker(location=[p2.y, p2.x], radius=2, color='blue', fill=True,
            fill_opacity=0.9).add_to(m)
        folium.PolyLine(locations=[[p1.y, p1.x], [p2.y, p2.x]], color='purple', weight=2,
            opacity=0.6).add_to(m)
    name = 'pointsclose300_' + fig[-1]
    m.save(O + name + '.html')
    shot(name, *size)

for fig, loc, zoom, size in [('close_a', [55.71, 8.0], 10, (1264, 652)),
                             ('close_b', [55.4742, 8.4235], 16, (1246, 644))]:
    if fig not in which:
        continue
    trajs = pd.read_csv(D + 'close300.csv')
    trajs['traj1_geom'] = trajs['traj1'].apply(wkt.loads)
    trajs['traj2_geom'] = trajs['traj2'].apply(wkt.loads)
    m = folium.Map(location=loc, zoom_start=zoom, tiles=None)
    VectorTiles('positron').add_to(m)
    for _, row in trajs.iterrows():
        for line in lines_of(row['traj1_geom']):
            folium.PolyLine(locations=latlon(line), color='red', weight=2, opacity=0.7,
                tooltip=f"traj1 MMSI: {row['MMSI']}").add_to(m)
        for line in lines_of(row['traj2_geom']):
            folium.PolyLine(locations=latlon(line), color='green', weight=2, opacity=0.7,
                tooltip=f"traj2 MMSI: {row['MMSI_1']}").add_to(m)
    if fig == 'close_a':   # the trajectories that leave the harbour of Esbjerg
        m.fit_bounds([[55.426, 7.576], [56.002, 8.426]])
    name = 'close300_' + fig[-1]
    m.save(O + name + '.html')
    if fig == 'close_a':   # the town that the text names (OpenStreetMap place node), labelled in the overlay
        shot(name, *size, incl='width=0.45\\textwidth', labels=True,
             places=[('Esbjerg', 55.4664892, 8.4520751, 'south west')])
    else:
        shot(name, *size)

# The two maps are the panels (a) and (b) of one figure, drawn at the same scale: the same zoom, the
# same layout size and the same printed width, centred on the same port, so that the buffers of
# 500 m and 1000 m keep their ratio of sizes on the page
for fig, radius, cmap_name, label_color, zoom, size in [
        ('copenh', 500, 'tab20', 'red', 14, (848, 848)),
        ('copenhstop', 1000, 'Set1', 'black', 14, (848, 848))]:
    incl = 'width=0.48\\textwidth'
    if fig not in which:
        continue
    df = pd.read_csv(D + fig + '.csv')
    df['trip_geom'] = df['trip_wkt'].apply(wkt.loads)
    center = wkt.loads(df['buffer_center'].iloc[0])
    m = folium.Map(location=[center.y, center.x], zoom_start=zoom, tiles=None)
    VectorTiles('positron').add_to(m)
    folium.Circle(location=[center.y, center.x], radius=radius, color='red', weight=1,
        fill=True, fill_color='red', fill_opacity=0.2).add_to(m)
    unique_ids = df['mmsi'].unique()
    colors = matplotlib.colormaps[cmap_name].resampled(max(len(unique_ids), 2))
    color_map = {mmsi: mcolors.to_hex(colors(i)) for i, mmsi in enumerate(unique_ids)}
    for _, row in df.iterrows():
        folium.GeoJson(row['trip_geom'],
            style_function=lambda x, color=color_map[row['mmsi']]: {'color': color, 'weight': 2},
            tooltip=f"MMSI: {row['mmsi']}").add_to(m)
    folium.Marker(location=[center.y, center.x], icon=folium.DivIcon(
        html=f'<div style="font-size:14px; color:{label_color}"><b>Copenhagen Port</b></div>')
        ).add_to(m)
    m.save(O + fig + '.html')
    # A dot marks the centre of the buffer; the two panels share one scale, so a name set at caption
    # size would read as a different size relative to each circle and is left out
    shot(fig, *size, incl=incl, labels='places',
         places=[('', center.y, center.x, 'north')])
