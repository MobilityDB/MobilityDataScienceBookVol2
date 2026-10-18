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
r = fig.canvas.get_renderer()
for i, ax in enumerate(axes):
    ext = ax.get_tightbbox(r).transformed(fig.dpi_scale_trans.inverted())
    fig.savefig(f"{OUT}/pymeosais2_{'ab'[i]}.png",
                bbox_inches=ext.expanded(1.02, 1.02), dpi=72)
    fig.savefig(f"{OUT}/pymeosais2_{'ab'[i]}.pdf",
                bbox_inches=ext.expanded(1.02, 1.02))
pymeos_finalize()
