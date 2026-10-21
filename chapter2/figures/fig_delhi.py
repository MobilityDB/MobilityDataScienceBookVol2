"""Delhi figures of chapter 2 (mpandas2-*): the explore() code printed in the chapter over the
OpenFreeMap vector styles (#VectorTiles in vtiles.py), printed to PDF at the size of each figure.
Usage: fig_delhi.py [name ...]  (default: all)."""
import math
import sys
from pathlib import Path
from delhi_common import *  # noqa: F401,F403  (tc, my_trajs, my_traj, my_traj_split, ...)
import folium
import matplotlib
from matplotlib.colors import ListedColormap, to_hex
from vtiles import VectorTiles
from vgprint import MM_PER_PX, print_map, categorical_legend, colorbar_of, write_overlay
sys.path.append(str(Path(__file__).resolve().parents[2] / 'chapter7' / 'figures'))
from pdf_simplify import simplify_printed  # noqa: E402

OUT = Path(__file__).resolve().parent / 'out'
OUT.mkdir(exist_ok=True)
CTRL = ('.leaflet-control-zoom', '.leaflet-control-scale', '.leaflet-control-layers')


def delhitrips():
    m = my_trajs.explore(column="deviceId", cmap="tab10", tiles=None,
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
    m = my_traj.explore(tiles=None, style_kwds={"weight": 4})
    VectorTiles("liberty-city").add_to(m)
    return m


def splits_detail():
    detail = my_traj_split.trajectories[1]
    detail.add_speed(overwrite=True)
    m = detail.to_line_gdf().explore(
        tiles=None, style_kwds={"weight": 4}, column="speed", vmin=0, vmax=20)
    VectorTiles("liberty-city").add_to(m)
    return m


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
        min_duration=timedelta(seconds=120), max_diameter=100
    )
    print("len(stop_points)", len(stop_points))
    m = my_trajs.explore(
        column="deviceId",
        tooltip="deviceId",
        popup=True,
        style_kwds={"weight": 4},
        name="Trajectories",
        tiles=None,
    )
    stop_points.explore(
        m=m,
        color="red",
        tooltip="stop_id",
        popup=True,
        marker_kwds={"radius": 7},
        name="Stop points",
    )
    VectorTiles("liberty-city").add_to(m)
    folium.LayerControl().add_to(m)
    return m


def stops_agg():
    generalized = mpd.MinDistanceGeneralizer(tc).generalize(tolerance=100)
    aggregator = mpd.TrajectoryCollectionAggregator(
        generalized,
        max_distance=1000,
        min_distance=100,
        min_stop_duration=timedelta(minutes=5),
    )
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
    'mpandas2-delhitrips': (delhitrips, 1724, 1032, 143.9926, ('view', 28.579, 77.221, 12),
                            ('.leaflet-control-layers',)),
    'mpandas2-delhispeeds': (delhispeeds, 1422, 1026, 143.9926, ('view', 28.559, 77.248, 12), CTRL),
    'mpandas2-delhitraj': (delhitraj, 1188, 984, 143.9926, ('view', 28.5677, 77.2227, 12), CTRL),
    'mpandas2-splits-detail': (splits_detail, 1706, 690, 143.9926, ('view', 28.5657, 77.2246, 15),
                               CTRL),
    'mpandas2-stops': (stops, 574, 478, 143.9926, ('bounds', 28.530, 77.166, 28.6205, 77.290),
                       CTRL),
    'mpandas2-segments': (segments, 572, 474, 143.9926,
                          ('bounds', 28.530, 77.166, 28.6205, 77.290), CTRL),
    'mpandas2-stops-collect': (stops_collect, 892, 636, 143.9926,
                               ('bounds', 28.4847, 77.1314, 28.6787, 77.4114), CTRL),
    'mpandas2-stops-agg': (stops_agg, 556, 620, 143.9926,
                           ('bounds', 28.5551, 77.1690, 28.6751, 77.2712), CTRL),
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
# \\includegraphics options of the figure in the chapter. Figs. 2.1, 2.2, 2.5 and 2.8 place their legend
# in the bottom left corner, which no trip crosses, in the 8 pt the colour bar of Fig. 2.4 is set in
# (FS of fig_charts_print.py).
OVERLAY = {
    'mpandas2-delhitrips': (('legend', 'south west'), 'width=0.8\\textwidth'),
    'mpandas2-delhispeeds': (('colorbar', 'Speed (m/s)', 3.5, 'south west'), 'width=0.8\\textwidth'),
    'mpandas2-splits-detail': (('colorbar', 'Speed (m/s)', 3.5, 'south west'), 'width=1.\\textwidth'),
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
    'mpandas2-splits-detail': ('width', TEXTWIDTH_MM),
    'mpandas2-stops': ('width', 0.42 * TEXTWIDTH_MM), 'mpandas2-segments': ('width', 0.42 * TEXTWIDTH_MM),
    'mpandas2-stops-collect': ('width', 0.8 * TEXTWIDTH_MM),
    'mpandas2-stops-agg': ('width', 0.6 * TEXTWIDTH_MM),
    # Fig. 2.10: the two maps side by side over the width of the text, one shape, one ground
    'mpandas2-smooth_a': ('width', 0.48 * TEXTWIDTH_MM), 'mpandas2-smooth_b': ('width', 0.48 * TEXTWIDTH_MM),
    'mpandas2-smooth-speed_a': ('height', 74), 'mpandas2-smooth-speed_b': ('height', 74),
}
# The maps whose paths #simplify_printed of chapter7/figures/pdf_simplify.py simplifies below half a
# printed pixel: all of them, since every vertex closer than a printed pixel costs a viewer time to
# draw and none of them shows
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


FONT_8PT = {'mpandas2-delhitrips', 'mpandas2-delhispeeds', 'mpandas2-splits-detail',
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
                     round(width_mm * h / w / 25.4, 4), bounds=bounds, hide=hide)
    if name in SIMPLIFIED:
        simplify_printed(f'{OUT}/{name}.pdf', width_mm)
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
                      comment='fig_delhi.py', **args)
