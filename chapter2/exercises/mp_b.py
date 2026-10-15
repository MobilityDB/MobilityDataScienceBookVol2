import warnings; warnings.filterwarnings("ignore")
import pandas as pd, movingpandas as mpd
from datetime import timedelta
df = pd.read_csv("../2021-01-30_all.csv", index_col=0)
tc = mpd.TrajectoryCollection(df, "deviceId", t="dateTime", x="long", y="lat")

cleaned = mpd.OutlierCleaner(tc).clean(v_max=60, units=("km", "h"))
rows = []
for raw, cln in zip(tc, cleaned):
    raw.add_speed(overwrite=True, units=("km", "h"))
    cln.add_speed(overwrite=True, units=("km", "h"))
    rows.append([raw.id, raw.size(), cln.size(), raw.df["speed"].max(),
                 cln.df["speed"].max(), raw.get_length() / 1000,
                 cln.get_length() / 1000])
res = pd.DataFrame(rows, columns=["bus", "n", "n_clean", "vmax", "vmax_clean",
                                  "km", "km_clean"]).set_index("bus")
print(res.round(1))
