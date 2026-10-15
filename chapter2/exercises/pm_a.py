import warnings; warnings.filterwarnings("ignore")
import pandas as pd
from pymeos import *
pymeos_initialize("UTC")

ais = pd.read_csv("aisinput.csv", parse_dates=["t"])
ais["instant"] = ais.apply(lambda r: TGeogPointInst(
    point=(r["longitude"], r["latitude"]), timestamp=r["t"]), axis=1)
ais["sog"] = ais.apply(lambda r: TFloatInst(value=r["sog"], timestamp=r["t"]),
    axis=1)
ships = ais.groupby("mmsi").aggregate({
    "instant": lambda x: TGeogPointSeq.from_instants(x, upper_inc=True),
    "sog": lambda x: TFloatSeq.from_instants(x, upper_inc=True),
}).rename({"instant": "trajectory"}, axis=1)

for mmsi, row in ships.iterrows():
    fast = row["sog"].at(FloatSpan(lower=10, upper=200, lower_inc=False))
    if fast is None:
        print(mmsi, "never above 10 knots")
        continue
    leg = row["trajectory"].at(fast.time())
    print(mmsi, fast.num_sequences(), fast.duration(),
          round(leg.length() / 1000, 1))
