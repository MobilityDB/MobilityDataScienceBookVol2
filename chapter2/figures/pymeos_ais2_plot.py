"""Last listing of the complete PyMEOS example of chapter 2: read one ship back from the table pymeos.Ships
and plot its trajectory and SOG (figures pymeosais2_a/b). Run with PSYCOPG_IMPL=python: the PyMEOS
psycopg loader decodes bytes, and the psycopg C implementation passes a memoryview."""
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pymeos import *
from pymeos.db.psycopg import MobilityDB
import movingpandas as mpd
from vtiles import VectorTiles
from vgprint import MM_PER_PX, pad_page, page_size_in, print_map, write_overlay

pymeos_initialize()
connection = MobilityDB.connect(host=os.environ.get("PGHOST", "localhost"),
                                port=int(os.environ.get("PGPORT", 5433)),
                                dbname=os.environ.get("PGDATABASE", "ais"),
                                user=os.environ.get("PGUSER", "postgres"),
                                password=os.environ.get("PGPASSWORD", "postgres"))
cursor = connection.cursor()
cursor.execute("SELECT * FROM pymeos.Ships WHERE MMSI = 219026257;")
mmsi, trajectory, sog = cursor.fetchone()
cursor.close()
print(mmsi, type(trajectory).__name__, trajectory.num_instants(), sog.num_instants(),
      trajectory.start_timestamp(), trajectory.end_timestamp(), sog.min_value(), sog.max_value(),
      trajectory.length())

# --- the listing printed in the chapter, from the line after cursor.close()
traj = mpd.Trajectory(trajectory.to_geometric().to_dataframe(), mmsi)
m = traj.explore(tiles=None, color="blue", style_kwds={"weight": 4})
VectorTiles("liberty").add_to(m)
fig, ax = plt.subplots(figsize=(10, 10))
sog.plot(axes=ax)
# --- end of the listing
# Panel (a) the map at the size, over the extent and with the towns of the maps pymeosais1_a/b
# (#bounds of pymeosais_view.py, which needs the trips written by pymeos_ais1.py), at the print scale
# of the maps of fig_delhi.py (MM_PER_PX); panel (b) the SOG chart, as high as the map, beside it.
from print_panels import TEXTWIDTH, print_panel_box
from pymeosais_view import HEIGHT_MM, PLACES, WIDTH_MM, bounds as view_bounds
html = f"{OUT}/pymeosais2_a.html"
m.save(html)
south, west, north, east = view_bounds(DATA)
box = trajectory.to_geometric().bounding_box()
assert west <= box.xmin() and box.xmax() <= east and south <= box.ymin() and box.ymax() <= north, \
    "the trip leaves the extent of the maps pymeosais1_a/b"
info = print_map(html, f"{OUT}/pymeosais2_a.pdf", round(WIDTH_MM / MM_PER_PX), round(HEIGHT_MM / MM_PER_PX),
                 round(WIDTH_MM / 25.4, 4), round(HEIGHT_MM / 25.4, 4),
                 bounds=(south, west, north, east), places=PLACES)
# The box of the chart is as high as the page of the map as Chrome printed it, and the page of the
# map is padded with the margins of the labels of the chart, so that the two boxes have one height
# and are aligned at the top
map_h = page_size_in(f"{OUT}/pymeosais2_a.pdf")[1]
under, above = print_panel_box(fig, ax, f"{OUT}/pymeosais2_b.pdf", 0.44 * TEXTWIDTH, map_h,
                               lw=0.5, ms=1.5)
pad_page(f"{OUT}/pymeosais2_a.pdf", under, above)
# The labels of the towns are placed on the padded page: their heights, measured from the top of the
# map, move down by the padding above it and are scaled to the padded height
labels = [dict(lb, y0=(above + lb['y0'] * map_h) / (map_h + under + above)) for lb in info['labels']]
write_overlay(f"{OUT}/pymeosais2_a_overlay.tex", "figs/chap2/pymeosais2_a.pdf", "width=0.48\\textwidth",
              "ovpymeosaisa", labels=labels, comment="pymeos_ais2_plot.py")
pymeos_finalize()
