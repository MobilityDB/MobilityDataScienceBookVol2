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

"""Delhi figures of chapter 2 (mpandas2-*): the explore() code printed in the chapter over the
OpenFreeMap vector styles (#VectorTiles in vtiles.py), printed to PDF at the size of each figure.
Usage: fig_delhi.py [name ...]  (default: all)."""
import math
import sys
from pathlib import Path
from delhi_common import *  # noqa: F401,F403  (tc, my_trajs, my_traj, my_traj_split, ...)
import folium
import geopandas as gpd
from shapely.geometry import box
import matplotlib
from matplotlib.colors import ListedColormap, to_hex
from vtiles import VectorTiles
from vgprint import MM_PER_PX, print_map, categorical_legend, colorbar_of, write_overlay
sys.path.append(str(Path(__file__).resolve().parents[2] / 'chapter7' / 'figures'))
from pdf_simplify import simplify_printed  # noqa: E402

OUT = Path(__file__).resolve().parent / 'out'
OUT.mkdir(exist_ok=True)
CTRL = ('.leaflet-control-zoom', '.leaflet-control-scale', '.leaflet-control-layers')
# The colours of the four parts of the split trajectory, those of their boxes in Fig. 2.3 and of their maps in
# Fig. 2.4, given to the numbers of the parts in the overlay of Fig. 2.3
PART_COLORS = ["#1f77b4", "#2ca02c", "#ff7f0e", "#d62728"]


def delhitrips():
    m = my_trajs.to_traj_gdf().explore(column="deviceId", cmap="tab10", tiles=None,
                                       style_kwds={"weight": 4})
    VectorTiles("liberty-city").add_to(m)
    return m


def delhispeeds():
    my_trajs.add_speed(overwrite=True)
    m = my_trajs.to_line_gdf().explore(tiles=None, style_kwds={"weight": 4},
                                       column="speed", vmin=0, vmax=20)
    VectorTiles("liberty-city").add_to(m)
    return m


def delhitraj():
    my_traj.add_speed(overwrite=True)
    m = my_traj.to_line_gdf().explore(tiles=None, style_kwds={"weight": 4},
                                      column="speed", vmin=0, vmax=20)
    colors = ["#1f77b4", "#2ca02c", "#ff7f0e", "#d62728"]
    for part, color in zip(my_traj_split, colors):
        gpd.GeoSeries([box(*part.get_bbox())], crs=4326).explore(
            m=m, color=color, style_kwds={"fill": False, "weight": 2})
    VectorTiles("liberty-city").add_to(m)
    return m


def delhitraj_places():
    """The number of each part of the split trajectory inside the north-east corner of its bounding
    box, which the trajectory does not cross; a number whose corner holds one already (the boxes of
    parts 1 and 3 nearly coincide) is set under it, a line of 3.5 mm lower: the labels of #print_map,
    drawn without a dot in the colour of the box by #write_overlay of vgprint.py."""
    s, _, n, _ = shown_bounds(('bounds',) + trips_bounds(), (TRIPS_W + 1) // 2, (TRIPS_H + 1) // 2)
    deg_per_mm = (n - s) / (0.8 * TEXTWIDTH_MM * TRIPS_H / TRIPS_W)
    places = []
    for i, part in enumerate(my_traj_split):
        _, _, east, north = part.get_bbox()
        near = [p[1] for p in places
                if abs(p[1] - north) < 3.5 * deg_per_mm and abs(p[2] - east) < 3.5 * deg_per_mm]
        if near:
            north = min(near) - 3.5 * deg_per_mm
        places.append((str(i + 1), north, east, 'north east'))
    return places


def split_part(i):
    """Fig. 2.4: the part i of the split trajectory in its colour, the map fitted to the part."""
    part = my_traj_split.trajectories[i]
    m = part.explore(tiles=None, color=PART_COLORS[i],
                     style_kwds={"weight": 4})
    w, s, e, n = part.get_bbox()
    m.fit_bounds([[s, w], [n, e]])
    VectorTiles("liberty-city").add_to(m)
    return m


def trips_bounds(margin=0.06, under=0.15):
    """The (south, west, north, east) of the four trajectories, with a margin of their extent, `under`
    of it under them: the one ground of Figs. 2.1, 2.2 and 2.3, which show the same trips, on which the
    boxes of the parts stay clear of the edges of the map and the legend or colour bar is set under
    the trips."""
    boxes = [t.get_bbox() for t in my_trajs]
    w, s = min(b[0] for b in boxes), min(b[1] for b in boxes)
    e, n = max(b[2] for b in boxes), max(b[3] for b in boxes)
    dx, dy = (e - w) * margin, (n - s) * margin
    return (s - (n - s) * under, w - dx, n + dy, e + dx)


def shape_of(bounds, width):
    """The (width, height) in px of a map of the given width showing the bounds (south, west, north,
    east) exactly, in the Web Mercator projection of Leaflet (#shown_bounds)."""
    s, w, n, e = bounds
    y = lambda lat: math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
    return width, round(width * (y(n) - y(s)) / math.radians(e - w))


# Figs. 2.1 to 2.3, 2.7 and 2.8: one ground and one shape, so that the maps print at the same height
TRIPS_W, TRIPS_H = shape_of(trips_bounds(), 1724)


def part_bounds(i, margin=0.04):
    """The (south, west, north, east) of the part i of the split trajectory, with a margin of its
    extent: the ground of the maps of that part."""
    w, s, e, n = my_traj_split.trajectories[i].get_bbox()
    dx, dy = (e - w) * margin, (n - s) * margin
    return (s - dy, w - dx, n + dy, e + dx)


def speed_map(traj):
    traj.add_speed(overwrite=True)
    m = traj.to_line_gdf().explore(tiles=None, style_kwds={"weight": 4},
                                   column="speed", vmin=0, vmax=15)
    VectorTiles("liberty-city").add_to(m)
    return m


def generalization(which):
    """Fig. 2.5: the second part of the split trajectory, and its DP and TDTR generalizations."""
    original_traj = my_traj_split.trajectories[1]
    if which == "a":
        return speed_map(original_traj)
    if which == "b":
        return speed_map(mpd.DouglasPeuckerGeneralizer(original_traj).generalize(
            tolerance=0.001))
    return speed_map(mpd.TopDownTimeRatioGeneralizer(original_traj).generalize(
        tolerance=0.001))


def _stops():
    my_traj_stop = my_traj_split.trajectories[2]
    detector = mpd.TrajectoryStopDetector(my_traj_stop)
    stop_points = detector.get_stop_points(
        min_duration=timedelta(seconds=60), max_diameter=100)
    m = my_traj_stop.explore(color="slategray", style_kwds={"weight": 4},
                             tiles=None, name="Trajectory")
    VectorTiles("liberty-city").add_to(m)
    stop_points.explore(
        m=m, color="deeppink", name="Stop points",
        style_kwds={"fillOpacity": 1, "style_function": lambda x:
                    {"radius": x["properties"]["duration_s"] ** 0.5 / 1.2}})
    return m, detector


def stops():
    return _stops()[0]


def segments():
    m, detector = _stops()
    stop_segments = detector.get_stop_segments(
        min_duration=timedelta(seconds=60), max_diameter=100)
    stop_segments.explore(m=m, color="orange", style_kwds={"weight": 6},
                          name="Stop segments")
    return m


def stops_collect():
    detector = mpd.TrajectoryStopDetector(my_trajs)
    stop_points = detector.get_stop_points(
        min_duration=timedelta(seconds=120), max_diameter=100)
    print("len(stop_points)", len(stop_points))
    m = my_trajs.explore(
        column="deviceId", tooltip="deviceId", popup=True, style_kwds={"weight": 4},
        name="Trajectories", tiles=None)
    stop_points.explore(
        m=m, color="red", tooltip="stop_id", popup=True, marker_kwds={"radius": 7},
        name="Stop points")
    VectorTiles("liberty-city").add_to(m)
    folium.LayerControl().add_to(m)
    return m


def stops_agg():
    generalized = mpd.MinDistanceGeneralizer(tc).generalize(tolerance=100)
    aggregator = mpd.TrajectoryCollectionAggregator(
        generalized, max_distance=1000, min_distance=100,
        min_stop_duration=timedelta(minutes=5))
    pts = aggregator.get_significant_points_gdf()
    clusters = aggregator.get_clusters_gdf()
    print("significant points", len(pts), "clusters", len(clusters))
    m = pts.explore(marker_kwds={"radius": 7}, name="Significant points", tiles=None)
    clusters.explore(m=m, color="red",
                     marker_kwds={"radius": 7}, name="Cluster centroids")
    VectorTiles("liberty-city").add_to(m)
    folium.LayerControl().add_to(m)
    return m


_SMOOTH = {}


def _smooth():
    if not _SMOOTH:
        split_tr = mpd.ObservationGapSplitter(tc).split(gap=timedelta(minutes=15))
        smooth = mpd.KalmanSmootherCV(split_tr).smooth(
            process_noise_std=0.1, measurement_noise_std=10)
        print(smooth)
        _SMOOTH.update(split_tr=split_tr, smooth=smooth)
    return _SMOOTH["split_tr"], _SMOOTH["smooth"]


def smooth_a():
    split_tr, smooth = _smooth()
    # tab20 as explore() spreads it over the devices, with blue for its pink and red for its
    # light blue
    n = split_tr.to_traj_gdf()["deviceId"].nunique()
    colors = [{"#e377c2": "blue", "#9edae5": "red"}.get(c, c) for c in
              map(to_hex, matplotlib.colormaps["tab20"].resampled(n).colors)]
    kwargs = {"column": "deviceId", "cmap": ListedColormap(colors), "legend": False,
              "style_kwds": {"weight": 4}, "tiles": None}
    m = split_tr.to_traj_gdf().explore(**kwargs)
    VectorTiles("liberty-city").add_to(m)
    return m


def smooth_b():
    """Smoothed twin of #smooth_a (same kwargs, the smooth collection)."""
    split_tr, smooth = _smooth()
    # tab20 as explore() spreads it over the devices, with blue for its pink and red for its
    # light blue
    n = split_tr.to_traj_gdf()["deviceId"].nunique()
    colors = [{"#e377c2": "blue", "#9edae5": "red"}.get(c, c) for c in
              map(to_hex, matplotlib.colormaps["tab20"].resampled(n).colors)]
    kwargs = {"column": "deviceId", "cmap": ListedColormap(colors), "legend": False,
              "style_kwds": {"weight": 4}, "tiles": None}
    m = smooth.to_traj_gdf().explore(**kwargs)
    VectorTiles("liberty-city").add_to(m)
    return m


def smooth_speed_a():
    split_tr, smooth = _smooth()
    kwargs = {"column": "speed", "cmap": "viridis", "vmin": 0, "vmax": 20,
              "style_kwds": {"weight": 4}, "tiles": None}
    split_tr.add_speed(overwrite=True)
    m = split_tr.trajectories[8].to_line_gdf().explore(**kwargs)
    VectorTiles("liberty-city").add_to(m)
    return m


def smooth_speed_b():
    """Smoothed twin of #smooth_speed_a (same kwargs, the smooth collection)."""
    split_tr, smooth = _smooth()
    kwargs = {"column": "speed", "cmap": "viridis", "vmin": 0, "vmax": 20,
              "style_kwds": {"weight": 4}, "tiles": None}
    smooth.add_speed(overwrite=True)
    m = smooth.trajectories[8].to_line_gdf().explore(**kwargs)
    VectorTiles("liberty-city").add_to(m)
    return m


# name -> (builder, width, height in px at dpi, dpi, extent, hidden controls); the width and height
# give the shape of the map and, with the extent, the ground it shows
# extent: ('view', lat, lon, zoom) or ('bounds', south, west, north, east)
FIGS = {
    # Figs. 2.1 to 2.3: the four trips, their speeds, and the first trip with its splits, over one ground
    'mpandas2-delhitrips': (delhitrips, TRIPS_W, TRIPS_H, 143.9926, ('bounds',) + trips_bounds(),
                            ('.leaflet-control-layers',)),
    'mpandas2-delhispeeds': (delhispeeds, TRIPS_W, TRIPS_H, 143.9926, ('bounds',) + trips_bounds(), CTRL),
    'mpandas2-delhitraj': (delhitraj, TRIPS_W, TRIPS_H, 143.9926, ('bounds',) + trips_bounds(), CTRL),
    # Fig. 2.4: four square maps, each fitted to its part
    **{f'mpandas2-splits_{p}': (lambda i=i: split_part(i), 1000, 1000, 143.9926,
                                ('bounds',) + part_bounds(i), CTRL)
       for i, p in enumerate('abcd')},
    # Fig. 2.5: three maps of one shape over the ground of the second part of the trajectory
    **{f'mpandas2-generalization_{p}': (lambda p=p: generalization(p), 1706, 900, 143.9926,
                                        ('bounds',) + part_bounds(1), CTRL)
       for p in 'abc'},
    # Fig. 2.6: the stops and the segments of the third part, side by side over its ground
    'mpandas2-stops': (stops, 574, 620, 143.9926, ('bounds',) + part_bounds(2), CTRL),
    'mpandas2-segments': (segments, 574, 620, 143.9926, ('bounds',) + part_bounds(2), CTRL),
    # Figs. 2.7 and 2.8: the stops of the four trips and the aggregation of the collection, whose
    # points all lie on the ground of Figs. 2.1 to 2.3, over that ground and in that shape
    'mpandas2-stops-collect': (stops_collect, TRIPS_W, TRIPS_H, 143.9926, ('bounds',) + trips_bounds(),
                               CTRL),
    'mpandas2-stops-agg': (stops_agg, TRIPS_W, TRIPS_H, 143.9926, ('bounds',) + trips_bounds(), CTRL),
    'mpandas2-smooth_a': (smooth_a, 648, 888, 143.9926,
                          ('bounds', 28.554, 77.2035, 28.629, 77.2545), CTRL),
    'mpandas2-smooth_b': (smooth_b, 648, 888, 143.9926,
                          ('bounds', 28.554, 77.2035, 28.629, 77.2545), CTRL),
    'mpandas2-smooth-speed_a': (smooth_speed_a, 679, 888, 143.9926,
                                ('bounds', 28.511, 77.2365, 28.595, 77.2935), CTRL),
    'mpandas2-smooth-speed_b': (smooth_speed_b, 688, 888, 143.9926,
                                ('bounds', 28.511, 77.2365, 28.595, 77.2935), CTRL),
}

# name -> overlay of the text the map image does not carry: ('legend', anchor) for the categorical
# legend of explore(), ('colorbar', title, width in cm[, anchor]) for its colour bar; and the
# \\includegraphics options of the figure in the chapter. Figs. 2.1, 2.2, 2.3, 2.5 and 2.7 place their
# legend or colour bar in the bottom left corner, which no trip crosses, in 8 pt (FS of print_panels.py).
OVERLAY = {
    'mpandas2-delhitrips': (('legend', 'south west'), 'width=0.8\\textwidth'),
    'mpandas2-delhispeeds': (('colorbar', 'Speed (m/s)', 3.5, 'south west'), 'width=0.8\\textwidth'),
    'mpandas2-delhitraj': (('colorbar', 'Speed (m/s)', 3.5, 'south west'), 'width=0.8\\textwidth'),
    **{f'mpandas2-generalization_{p}': (('colorbar', 'Speed (m/s)', 3.5, 'south west'),
                                        'width=0.8\\textwidth') for p in 'abc'},
    'mpandas2-stops-collect': (('legend', 'south west'), 'width=0.8\\textwidth'),
    'mpandas2-smooth-speed_a': (('colorbar', 'Speed (m/s)', 2.6), 'height=7.4cm'),
    'mpandas2-smooth-speed_b': (('colorbar', 'Speed (m/s)', 2.6), 'height=7.4cm'),
}
# name -> the side and the length in mm at which the book prints the map (\includegraphics of
# chapter2.tex)
TEXTWIDTH_MM = 332.89723 / 72.27 * 25.4
PRINTED = {
    'mpandas2-delhitrips': ('width', 0.8 * TEXTWIDTH_MM),
    'mpandas2-delhispeeds': ('width', 0.8 * TEXTWIDTH_MM),
    'mpandas2-delhitraj': ('width', 0.8 * TEXTWIDTH_MM),
    **{f'mpandas2-generalization_{p}': ('width', 0.8 * TEXTWIDTH_MM) for p in 'abc'},
    **{f'mpandas2-splits_{p}': ('width', 0.48 * TEXTWIDTH_MM) for p in 'abcd'},
    'mpandas2-stops': ('width', 0.42 * TEXTWIDTH_MM), 'mpandas2-segments': ('width', 0.42 * TEXTWIDTH_MM),
    'mpandas2-stops-collect': ('width', 0.8 * TEXTWIDTH_MM),
    'mpandas2-stops-agg': ('width', 0.8 * TEXTWIDTH_MM),
    # Fig. 2.9: the two maps side by side over the width of the text, one shape, one ground
    'mpandas2-smooth_a': ('width', 0.48 * TEXTWIDTH_MM), 'mpandas2-smooth_b': ('width', 0.48 * TEXTWIDTH_MM),
    'mpandas2-smooth-speed_a': ('height', 74), 'mpandas2-smooth-speed_b': ('height', 74),
}
# The maps whose paths #simplify_printed of chapter7/figures/pdf_simplify.py simplifies below half a
# printed pixel and whose page it then rewrites by #squeeze: all of them, since every vertex closer than
# a printed pixel and every area that Chromium fills and then strokes as a second path cost a viewer
# time to draw and none of them shows
SIMPLIFIED = set(FIGS)


def shown_bounds(ext, css_w, css_h):
    """The (south, west, north, east) that a Leaflet map of css_w x css_h CSS px shows for the extent
    ext of FIGS, in the Web Mercator projection of Leaflet: setView centres the view at its zoom;
    fitBounds without padding and with zoomSnap 0 takes the largest zoom at which the bounds fit and
    centres them."""
    def project(lat, lon):
        y = math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
        return (lon + 180) / 360 * 256, (1 - y / math.pi) / 2 * 256

    def unproject(x, y):
        return (math.degrees(2 * math.atan(math.exp((1 - 2 * y / 256) * math.pi)) - math.pi / 2),
                x / 256 * 360 - 180)

    if ext[0] == 'view':
        (cx, cy), scale = project(ext[1], ext[2]), 2 ** ext[3]
    else:
        x0, y1 = project(ext[1], ext[2])
        x1, y0 = project(ext[3], ext[4])
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        scale = min(css_w / (x1 - x0), css_h / (y1 - y0))
    s, w = unproject(cx - css_w / 2 / scale, cy + css_h / 2 / scale)
    n, e = unproject(cx + css_w / 2 / scale, cy - css_h / 2 / scale)
    return s, w, n, e


# name -> the places of #print_map, the labels its overlay draws
PLACES = {'mpandas2-delhitraj': delhitraj_places}

FONT_8PT = {'mpandas2-delhitrips', 'mpandas2-delhispeeds', 'mpandas2-delhitraj',
            'mpandas2-generalization_a', 'mpandas2-generalization_b', 'mpandas2-generalization_c',
            'mpandas2-stops-collect'}

names = sys.argv[1:] or list(FIGS)
for name in names:
    build, w, h, dpi, ext, hide = FIGS[name]
    m = build()
    html = f'{OUT}/{name}.html'
    m.save(html)
    # The extent the map shows at the size of FIGS, laid out at its printed size in mm / MM_PER_PX
    side, mm = PRINTED[name]
    width_mm = mm if side == 'width' else mm * w / h
    css_w = round(width_mm / MM_PER_PX)
    css_h = round(css_w * h / w)
    bounds = shown_bounds(ext, (w + 1) // 2, (h + 1) // 2)
    info = print_map(html, f'{OUT}/{name}.pdf', css_w, css_h, round(width_mm / 25.4, 4),
                     round(width_mm * h / w / 25.4, 4), bounds=bounds, hide=hide,
                     places=PLACES[name]() if name in PLACES else ())
    if name in SIMPLIFIED:
        simplify_printed(f'{OUT}/{name}.pdf', width_mm, squeezed=True)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
    if name in OVERLAY:
        (kind, *a), incl = OVERLAY[name]
        pfx = 'ov' + ''.join(ch for ch in name.split('-', 1)[1] if ch.isalpha())
        args = {}
        if kind == 'legend':
            title, items = categorical_legend(html)
            args['legend'] = (title, [(lab, c, 'line') for c, lab in items])
            args['legend_at'] = a[0]
        else:
            args['colorbar'] = (a[0], colorbar_of(m), a[1])
            if len(a) > 2:
                args['colorbar_at'] = a[2]
        if name in FONT_8PT:
            args['font'] = r'\fontsize{8}{9.5}\selectfont'
        write_overlay(f'{OUT}/{name}_overlay.tex', f'figs/chap2/{name}.pdf', incl, pfx,
                      labels=[dict(lb, dot=False, color=PART_COLORS[int(lb['text']) - 1])
                              for lb in info['labels']] if name in PLACES else (),
                      comment='fig_delhi.py', **args)
