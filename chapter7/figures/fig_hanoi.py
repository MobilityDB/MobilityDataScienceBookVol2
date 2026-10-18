"""Figures of the BerlinMOD-Hanoi section of Chapter 7, drawn with the Folium code of the
companion notebook chapter7/hanoi-book.ipynb (cells of Figs. tripsHanoi to tripsinstants) over the
SVG vector basemap of `#VectorTiles` printed in the chapter (vtiles.py),
printed by `#print_map` of vgprint.py as `#shot` of fig_md.py does, from the CSV files written
by hanoi_figdata.sql (DuckDB) or hanoi_figdata_pg.sql (MobilityDB), whose geometries are in
longitude and latitude. Every map PDF is all vectors and carries no text; a legend the caption
needs is a TikZ overlay written by `#write_overlay`. Each map is laid out at half its pixel size
(device scale 2). tripdistricts, which has no basemap, is the matplotlib figure of the
notebook saved as a PDF."""
import sys
import random
import colorsys
import pandas as pd
import folium
import matplotlib
import matplotlib.colors as mcolors
from branca.colormap import linear
from shapely import wkt
from shapely.geometry import (LineString, MultiLineString, Point, MultiPoint,
                              GeometryCollection, mapping)

from vtiles import VectorTiles
from vgprint import print_map, write_overlay
from vghybrid import print_map_hybrid, print_dpi, TEXTWIDTH_MM
from pdf_simplify import simplify_printed

D = 'data/hanoi/'
O = 'out/'
which = sys.argv[1:] or ['tripsHanoi', 'municipalitiesHanoi', 'maxtripmuni', 'tripdistricts',
                         'totaldistpermuni', 'closetrips', 'closetraj_a', 'closetraj_b',
                         'tripsinstants']


def lines_of(geom):
    """The polylines of a trajectory: the parts of a MultiLineString or GeometryCollection, a
    point standing for a degenerate line, as `#normalize_geom` of the notebook does."""
    if geom is None or geom.is_empty:
        return []
    if isinstance(geom, LineString):
        return [geom]
    if isinstance(geom, Point):
        return [LineString([geom, geom])]
    if isinstance(geom, (MultiLineString, MultiPoint, GeometryCollection)):
        return [l for g in geom.geoms for l in lines_of(g)]
    return []


def latlon(line):
    return [(pt[1], pt[0]) for pt in line.coords]


def bounds_of(geoms, pad=0.0):
    """(south, west, north, east) of the geometries, widened by pad times their extent."""
    xs0, ys0, xs1, ys1 = zip(*[g.bounds for g in geoms])
    dx, dy = (max(xs1) - min(xs0)) * pad, (max(ys1) - min(ys0)) * pad
    return (min(ys0) - dy, min(xs0) - dx, max(ys1) + dy, max(xs1) + dx)


def new_map(style):
    m = folium.Map(location=[21.03, 105.85], zoom_start=11, tiles=None)
    VectorTiles(style).add_to(m)
    return m


def save(m, name, size, bounds=None, view=None, incl=None, width=None, hybrid=False, **overlay):
    """`#shot` of fig_md.py: print the map with `#print_map` at half the pixel size `size`
    (device scale 2), or, when hybrid, with `#print_map_hybrid` of vghybrid.py, its dense trips one
    lossless image of the printed pixels at 300 dpi over the vector basemap, as `#shot` of
    fig_duck.py does; when width (the fraction of \\textwidth at which the book prints the map) is
    given, the paths of the map are simplified below half a printed pixel by `#simplify_printed` of
    pdf_simplify.py; when incl (the \\includegraphics options of chapter7.tex) is given, write
    O + name_overlay.tex with the legend or colour bar of `overlay`."""
    m.save(O + name + '.html')
    if hybrid:
        info = print_map_hybrid(O + name + '.html', O + name + '.pdf', round(size[0] / 2),
                                round(size[1] / 2), view=view, bounds=bounds,
                                dpi=print_dpi(round(size[0] / 2), width))
    else:
        info = print_map(O + name + '.html', O + name + '.pdf', round(size[0] / 2),
                         round(size[1] / 2), view=view, bounds=bounds)
    if width:
        simplify_printed(O + name + '.pdf', width * TEXTWIDTH_MM)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'], flush=True)
    if incl:
        write_overlay(O + name + '_overlay.tex', f'figs/chap7/{name}.pdf', incl,
                      'ov' + ''.join(c for c in name if c.isalpha()),
                      comment=sys.argv[0].split('/')[-1], **overlay)


munis = pd.read_csv(D + 'municipalities.csv')
munis['geom'] = munis['geo'].apply(wkt.loads)
# the colours of the districts, as the notebook assigns them (cell 27) with
# seaborn.color_palette('hls', n): n hues from 0.01, at lightness 0.6 and saturation 0.65
munis['color'] = [mcolors.to_hex(colorsys.hls_to_rgb((i / len(munis) + 0.01) % 1, 0.6, 0.65))
                  for i in range(len(munis))]


def add_munis(m, opacity=0.6, weight=0.8):
    for _, row in munis.iterrows():
        folium.GeoJson(mapping(row['geom']), style_function=lambda f, c=row['color']: {
            'fillColor': c, 'color': c, 'weight': weight, 'fillOpacity': opacity}).add_to(m)


if {'tripsHanoi', 'municipalitiesHanoi'} & set(which):
    trips = pd.read_csv(D + 'trips.csv')
    trips['geom'] = trips['traj'].apply(wkt.loads)

if 'tripsHanoi' in which:
    m = new_map('liberty-city')
    for g in trips['geom']:
        for line in lines_of(g):
            folium.PolyLine(latlon(line), color='#1010ee', weight=2, opacity=0.9).add_to(m)
    save(m, 'tripsHanoi', (1884, 1036), bounds=(20.955, 105.745, 21.085, 105.945),
         width=0.8, hybrid=True)

if 'municipalitiesHanoi' in which:
    m = new_map('liberty-city')
    add_munis(m, opacity=0.45)
    for g in trips['geom']:
        for line in lines_of(g):
            folium.PolyLine(latlon(line), color='#1010ee', weight=1.5, opacity=0.8).add_to(m)
    save(m, 'municipalitiesHanoi', (1882, 1030), bounds=(20.86, 105.565, 21.125, 106.005),
         width=0.8, hybrid=True)

if 'maxtripmuni' in which:
    df = pd.read_csv(D + 'maxtripmuni.csv')
    trip = wkt.loads(df['trajectory'].iloc[0])
    m = new_map('positron')
    # the municipalities the trip crosses take, in the order the trip enters them, the colours of
    # tab10 but its red and grey, and the others are grey, each bounded by a white line, so that
    # the crossings can be counted on the map
    palette = [c for i, c in enumerate(matplotlib.colormaps['tab10'].colors) if i not in (3, 7)]
    crossed = [i for i in munis.index if munis.at[i, 'geom'].intersects(trip)]
    crossed.sort(key=lambda i: trip.project(munis.at[i, 'geom'].intersection(trip)
                                             .representative_point()))
    colour = {i: mcolors.to_hex(palette[k % len(palette)]) for k, i in enumerate(crossed)}
    for i, row in munis.iterrows():
        c = colour.get(i, '#b4b4b4')
        folium.GeoJson(mapping(row['geom']), style_function=lambda f, c=c: {
            'fillColor': c, 'color': 'white', 'weight': 1.2, 'fillOpacity': 0.6}).add_to(m)
    for line in lines_of(trip):
        folium.PolyLine(latlon(line), color='crimson', weight=2, opacity=1).add_to(m)
    save(m, 'maxtripmuni', (1154, 1162), bounds=bounds_of(list(munis['geom']), 0.02))

if 'totaldistpermuni' in which:
    # the choropleth of the notebook (cell 44); its scale goes to the LaTeX figure, not the map
    km = pd.read_csv(D + 'totaldist.csv')
    g = munis.merge(km, left_on='municipalityname', right_on='municipalityname', how='left')
    vmax = 10000 if g['TotalKm'].max() <= 10000 else 1000 * -(-g['TotalKm'].max() // 1000)
    colormap = linear.Oranges_09.scale(0, vmax).to_step(n=10)
    m = new_map('positron')
    for _, row in g.iterrows():
        c = colormap(row['TotalKm']) if pd.notna(row['TotalKm']) else 'lightgrey'
        folium.GeoJson(mapping(row['geom']), style_function=lambda f, c=c: {
            'fillColor': c, 'color': 'white', 'weight': 1, 'fillOpacity': 0.8}).add_to(m)
    save(m, 'totaldistpermuni', (986, 728), bounds=bounds_of(list(munis['geom']), 0.22),
         incl='width=0.7\\textwidth', width=0.7,
         colorbar=('Total kilometers traveled', colormap, 3.0))

if 'closetrips' in which:
    df = pd.read_csv(D + 'closepairs.csv')
    row = df.iloc[0]
    g1, g2 = wkt.loads(row['Traj1']), wkt.loads(row['Traj2'])
    m = new_map('positron')
    for line in lines_of(g1):
        folium.PolyLine(latlon(line), color='blue', weight=4, opacity=0.9).add_to(m)
    for line in lines_of(g2):
        folium.PolyLine(latlon(line), color='red', weight=2, opacity=0.7).add_to(m)
    # the legend of the notebook (cell 47), as a TikZ overlay
    save(m, 'closetrips', (1532, 848), bounds=bounds_of([g1, g2], 0.03),
         incl='width=0.8\\textwidth', legend_at='south west',
         legend=('Trajectories', [(f"Vehicle {row['VehicleId1']}", '#0000FF', 'line'),
                                  (f"Vehicle {row['VehicleId2']}", '#FF0000', 'line')]))

if {'closetraj_a', 'closetraj_b'} & set(which):
    df = pd.read_csv(D + 'closetraj.csv')
    df['g1'] = df['geom1'].apply(wkt.loads)
    df['g2'] = df['geom2'].apply(wkt.loads)
    # the detail is centred on the midpoint of the longest stretch along which two vehicles meet
    longest = max((line for g in df['g1'] for line in lines_of(g)), key=lambda line: line.length)
    centre = longest.interpolate(0.5, normalized=True)
    for fig, size in [('closetraj_a', (650, 604)), ('closetraj_b', (588, 542))]:
        if fig not in which:
            continue
        m = new_map('positron')
        for _, row in df.iterrows():
            for line in lines_of(row['g1']):
                folium.PolyLine(latlon(line), color='#0066FF', weight=5, opacity=1).add_to(m)
            for line in lines_of(row['g2']):
                folium.PolyLine(latlon(line), color='#FF0000', weight=5, opacity=1).add_to(m)
        if fig == 'closetraj_a':
            save(m, fig, size, bounds=bounds_of(list(df['g1']) + list(df['g2']), 0.05))
        else:
            # the detail: one meeting along a street
            save(m, fig, size, view=(centre.y, centre.x, 18))

if 'tripsinstants' in which:
    df = pd.read_csv(D + 'tripsinstants.csv')
    df['traj'] = df['trajectory'].apply(wkt.loads)
    df['pt'] = df['point'].apply(wkt.loads)
    m = new_map('positron')
    for g in df['traj']:
        for line in lines_of(g):
            folium.PolyLine(latlon(line), color='blue', weight=3, opacity=0.9).add_to(m)
    for p in df['pt']:
        folium.CircleMarker(location=(p.y, p.x), radius=4, color='red', fill=True,
                            fill_opacity=0.9).add_to(m)
    save(m, 'tripsinstants', (2018, 1188),
         bounds=bounds_of(list(df['traj'].drop_duplicates()), 0.0), width=0.8)

def trip_colors(n):
    """`#get_trip_colors` of the notebook (cell 34)."""
    og = list(mcolors.TABLEAU_COLORS.values())
    while len(og) < n:
        og = og * 2
    return random.sample(og, n)


def poly_patch(geom, color):
    """The filled district that `GeoDataFrame.plot(color=..., alpha=0.6)` draws in the notebook
    (cell 38); geopandas is not installed here, so the polygon goes to matplotlib as a path, as
    `#lines_of` hands the trajectories to it."""
    from matplotlib.patches import PathPatch
    from matplotlib.path import Path
    polys = geom.geoms if hasattr(geom, 'geoms') else [geom]
    verts, codes = [], []
    for p in polys:
        for ring in [p.exterior, *p.interiors]:
            c = list(ring.coords)
            verts += c
            codes += [Path.MOVETO] + [Path.LINETO] * (len(c) - 2) + [Path.CLOSEPOLY]
    return PathPatch(Path(verts, codes), facecolor=color, edgecolor='none', alpha=0.6)


if 'tripdistricts' in which:
    # the 2 x 3 panels of the notebook (cell 38): the six municipalities crossed by most trips,
    # each with its clipped trips, in EPSG:3857 on a square extent. As the charts of
    # chapter2/figures/fig_charts_print.py, the figure has the width at which the book prints it
    # (0.95\textwidth), so that it is not scaled; the Vietnamese names, whose letters the T1 fonts
    # of pdflatex lack, are set in the default font of matplotlib, DejaVu Sans, embedded as
    # TrueType, at the size whose x-height is that of the captions: \small, 8.5 TeX points of
    # LM Roman 9 (x-height 0.431 em), is 8.5 * 72 / 72.27 points of matplotlib, and DejaVu Sans has
    # an x-height of 0.547 em, so that at the same size it reads a quarter larger than the caption
    import matplotlib
    import matplotlib.pyplot as plt
    FS = 8.5 * 72 / 72.27 * 0.431 / 0.547
    matplotlib.rcParams.update({'pdf.fonttype': 42, 'font.size': FS, 'axes.titlesize': FS,
                                'axes.linewidth': 0.4})
    random.seed(1)
    counts = pd.read_csv(D + 'districtcount.csv')
    clips = pd.read_csv(D + 'districttrips.csv')
    m3857 = munis.set_index('municipalityname')
    W = 0.95 * 332.89723 / 72.27   # 0.95 svmono \textwidth, in inches
    fig, axes = plt.subplots(2, 3, figsize=(W, 0.76 * W), layout='constrained')
    for idx in range(6):
        ax = axes[idx // 3][idx % 3]
        name = counts.iloc[idx]['municipalityname']
        n = counts.iloc[idx]['intersectCount']
        g = wkt.loads(m3857.loc[name, 'geo3857'])
        ax.add_patch(poly_patch(g, m3857.loc[name, 'color']))
        sub = clips[clips['municipalityname'] == name]
        for c, w in zip(trip_colors(len(sub)), sub['trajClip']):
            for line in lines_of(wkt.loads(w)):
                xs, ys = line.xy
                ax.plot(xs, ys, color=c, linewidth=0.4, rasterized=True)
        minx, miny, maxx, maxy = g.bounds
        side = max(maxx - minx, maxy - miny) / 2
        cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
        ax.set_xlim(cx - side, cx + side)
        ax.set_ylim(cy - side, cy + side)
        ax.set_aspect('equal')
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_title(f'{name}\n{n} trips', fontsize=FS)
    # the clipped trips of each panel are one image of the pixels of the figure as the book
    # prints it, at 300 dpi; the districts and the titles stay vectors
    fig.savefig(O + 'tripdistricts.pdf', dpi=300)
