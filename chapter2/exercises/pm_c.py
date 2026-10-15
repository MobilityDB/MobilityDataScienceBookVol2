exec(open("pm_a.py").read().split("for mmsi, row")[0])
from collections import defaultdict

km = defaultdict(float)
for traj in ships["trajectory"]:
    for piece in traj.time_split("1 hour", "2026-01-20"):
        km[piece.start_timestamp().hour] += piece.length() / 1000
hourly = pd.Series(km).sort_index()
print(hourly.sort_values(ascending=False).head(3).round(1))
print(round(hourly.sum(), 1),
      round(sum(t.length() for t in ships["trajectory"]) / 1000, 1))
