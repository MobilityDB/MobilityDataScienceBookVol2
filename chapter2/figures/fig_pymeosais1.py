"""Figures pymeosais1_a/b of chapter 2: the explore() calls printed in the chapter, over the
OpenFreeMap liberty vector style the Delhi maps of the chapter use (#VectorTiles in vtiles.py)."""
import sys
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
import geopandas as gpd
import movingpandas as mpd
from vtiles import VectorTiles
from vgprint import MM_PER_PX, print_map, write_overlay
sys.path.append(str(Path(__file__).resolve().parents[2] / 'chapter7' / 'figures'))
from pdf_simplify import simplify_printed  # noqa: E402

# The towns that the chapter names for this trajectory (OpenStreetMap place nodes), labelled in the overlay
PLACES = [('Fredericia', 55.5652680, 9.7562169, 'south'), ('Middelfart', 55.4993014, 9.7392181, 'north')]

D = DATA


def traj_from_points(path):
    g = gpd.read_file(path)
    g = g.set_index('t') if 't' in g.columns else g
    return mpd.Trajectory(g, 1)


# The two panels are set side by side over the text width, each 0.48 of it wide with the shape of
# 527 x 422, laid out at their printed size in mm / MM_PER_PX, the scale of the Delhi maps of
# fig_delhi.py, and simplified below half a printed pixel by #simplify_printed of
# chapter7/figures/pdf_simplify.py
TEXTWIDTH_MM = 332.89723 / 72.27 * 25.4
width_mm = 0.48 * TEXTWIDTH_MM
height_mm = width_mm * 422 / 527
# Both panels show one ground: the trips of the two and the towns the chapter names, with a margin
# of MARGIN of its size on every side
MARGIN = 0.05
ext = gpd.GeoSeries(list(gpd.points_from_xy([p[2] for p in PLACES], [p[1] for p in PLACES]))
                    + [gpd.read_file(f'{D}/{n}.gpkg').to_crs(4326).union_all()
                       for n in ('pymeosais1_a', 'pymeosais1_b')]).total_bounds
dx, dy = MARGIN * (ext[2] - ext[0]), MARGIN * (ext[3] - ext[1])
bounds = (ext[1] - dy, ext[0] - dx, ext[3] + dy, ext[2] + dx)
for name in ('pymeosais1_a', 'pymeosais1_b'):
    g = gpd.read_file(f'{D}/{name}.gpkg')
    print(name, list(g.columns), len(g))
    tcol = [c for c in g.columns if 'time' in c.lower() or c == 't']
    traj = mpd.Trajectory(g.set_index(tcol[0]), 1)
    m = traj.explore(
        column="traj_id", cmap="turbo", tiles=None,
        tooltip="traj_id", popup=True, legend=False,)
    VectorTiles("liberty").add_to(m)
    html = f'{OUT}/{name}.html'
    m.save(html)
    view = None if len(sys.argv) < 2 else tuple(float(x) for x in sys.argv[1].split(','))
    info = print_map(html, f'{OUT}/{name}.pdf', round(width_mm / MM_PER_PX),
                     round(height_mm / MM_PER_PX), round(width_mm / 25.4, 4),
                     round(height_mm / 25.4, 4), view=view, bounds=None if view else bounds,
                     places=PLACES)
    simplify_printed(f'{OUT}/{name}.pdf', width_mm)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
    write_overlay(f'{OUT}/{name}_overlay.tex', f'figs/chap2/{name}.pdf', 'width=0.48\\textwidth',
                  'ov' + ''.join(c for c in name if c.isalpha()), labels=info['labels'],
                  comment='fig_pymeosais1.py')
