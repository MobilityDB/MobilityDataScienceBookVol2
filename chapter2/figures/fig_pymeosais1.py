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
from vgprint import print_map, write_overlay

# The towns that the chapter names for this trajectory (OpenStreetMap place nodes), labelled in the overlay
PLACES = [('Fredericia', 55.5652680, 9.7562169, 'south'), ('Middelfart', 55.4993014, 9.7392181, 'north')]

D = DATA


def traj_from_points(path):
    g = gpd.read_file(path)
    g = g.set_index('t') if 't' in g.columns else g
    return mpd.Trajectory(g, 1)


specs = [('pymeosais1_a', 527, 422, 150.0124), ('pymeosais1_b', 504, 406, 143.9926)]
for name, w, h, dpi in specs:
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
    info = print_map(html, f'{OUT}/{name}.pdf', (w + 1) // 2, (h + 1) // 2, round(w / dpi, 4),
                     round(h / dpi, 4), view=view, places=PLACES)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
    write_overlay(f'{OUT}/{name}_overlay.tex', f'figs/chap2/{name}.pdf', 'scale=0.55',
                  'ov' + ''.join(c for c in name if c.isalpha()), labels=info['labels'],
                  comment='fig_pymeosais1.py')
