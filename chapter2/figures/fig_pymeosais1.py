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
from pymeosais_view import HEIGHT_MM, PLACES, WIDTH_MM, bounds as view_bounds  # noqa: E402

D = DATA


def traj_from_points(path):
    g = gpd.read_file(path)
    g = g.set_index('t') if 't' in g.columns else g
    return mpd.Trajectory(g, 1)


# The two panels are set side by side over the text width, at the size, over the extent and with the
# towns of pymeosais_view.py (#bounds), which the map of pymeos_ais2_plot.py shares; laid out at their
# printed size in mm / MM_PER_PX, the scale of the Delhi maps of fig_delhi.py, and simplified below
# half a printed pixel by #simplify_printed of chapter7/figures/pdf_simplify.py
width_mm, height_mm = WIDTH_MM, HEIGHT_MM
bounds = view_bounds(D)
for name in ('pymeosais1_a', 'pymeosais1_b'):
    g = gpd.read_file(f'{D}/{name}.gpkg')
    print(name, list(g.columns), len(g))
    tcol = [c for c in g.columns if 'time' in c.lower() or c == 't']
    traj = mpd.Trajectory(g.set_index(tcol[0]), 1)
    m = traj.explore(tiles=None, color="blue", style_kwds={"weight": 4})
    VectorTiles("liberty").add_to(m)
    html = f'{OUT}/{name}.html'
    m.save(html)
    view = None if len(sys.argv) < 2 else tuple(float(x) for x in sys.argv[1].split(','))
    info = print_map(html, f'{OUT}/{name}.pdf', round(width_mm / MM_PER_PX),
                     round(height_mm / MM_PER_PX), round(width_mm / 25.4, 4),
                     round(height_mm / 25.4, 4), view=view, bounds=None if view else bounds,
                     places=PLACES)
    simplify_printed(f'{OUT}/{name}.pdf', width_mm, squeezed=True)
    print(name, 'zoom', round(info['zoom'], 3), 'tiles', info['tiles'])
    write_overlay(f'{OUT}/{name}_overlay.tex', f'figs/chap2/{name}.pdf', 'width=0.48\\textwidth',
                  'ov' + ''.join(c for c in name if c.isalpha()), labels=info['labels'],
                  comment='fig_pymeosais1.py')
