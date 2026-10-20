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

fig, axes = plt.subplots(1, 2, figsize=(20, 10))
trajectory.plot(axes=axes[0])
sog.plot(axes=axes[1])
plt.suptitle(f"Ship {mmsi}")
fig.savefig(f"{OUT}/pymeosais2_full.png", dpi=72)
# Each panel at the size at which the book prints it, 6 cm high, two side by side: the trajectory
# a map, the SOG a chart
from print_panels import CM, TEXTWIDTH, print_panel
print_panel(fig, axes[0], f"{OUT}/pymeosais2_a.pdf", 0.44 * TEXTWIDTH, 6 * CM, map_=True, lw=0.8)
print_panel(fig, axes[1], f"{OUT}/pymeosais2_b.pdf", 0.44 * TEXTWIDTH, 6 * CM, lw=0.5, ms=1.5)
pymeos_finalize()
