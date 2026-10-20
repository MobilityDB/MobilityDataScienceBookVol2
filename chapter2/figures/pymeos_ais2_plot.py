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
from vgprint import MM_PER_PX, print_map

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
# Panel (a) the map over the extent of the trip, at the print scale of the maps of fig_delhi.py
# (MM_PER_PX); panel (b) the SOG chart. Both are printed 6 cm high, side by side.
from print_panels import CM, TEXTWIDTH, print_panel
html = f"{OUT}/pymeosais2_a.html"
m.save(html)
box = trajectory.to_geometric().bounding_box()
# A margin of a twentieth of the extent, so that the ends of the trip stay inside the frame
dx, dy = (box.xmax() - box.xmin()) / 20, (box.ymax() - box.ymin()) / 20
width_mm, height_mm = 0.48 * TEXTWIDTH * 25.4, 60
print_map(html, f"{OUT}/pymeosais2_a.pdf", round(width_mm / MM_PER_PX), round(height_mm / MM_PER_PX),
          round(width_mm / 25.4, 4), round(height_mm / 25.4, 4),
          bounds=(box.ymin() - dy, box.xmin() - dx, box.ymax() + dy, box.xmax() + dx))
print_panel(fig, ax, f"{OUT}/pymeosais2_b.pdf", 0.44 * TEXTWIDTH, 6 * CM, lw=0.5, ms=1.5)
pymeos_finalize()
