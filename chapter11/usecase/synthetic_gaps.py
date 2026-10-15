"""Compare the reconstructions of synthetic gaps of increasing length on moving vessels. For each
vessel of Ships, the first sequence of its trip that lasts 181 minutes or more gives a stretch of 181
positions sampled every minute with tsample; the stretches of vessels moving at a mean speed of 3 knots
or more are kept. The central K minutes of each stretch, for K from 5 to 120, are hidden and
reconstructed in three ways: by the pretrained model, which receives the coordinates, times, and
kinematics of the visible positions and no descriptions, as the model coordinates of the use case but
with the kinematics; by the straight segment between the two visible positions that bound the hidden
block, as the baseline linear; and by the cubic Hermite curve between them whose tangents are the
reported speed and course at those two positions. For each K, the script prints the number of
stretches, the median and the mean over the stretches of the mean haversine error of each method at
the hidden minutes, in meters, and the share of stretches in which the curve is more accurate than
the segment.

    THESIS=<checkout of MobilityDB/FoundationModel at 8fc3ca2> python3 synthetic_gaps.py

The database is the one named by the PostgreSQL environment variables (PGDATABASE, PGHOST, ...), and
the model is the checkpoint models/checkpoints/best.pt of THESIS, loaded as run_model.py loads it.
"""
import math, os, sys, statistics as st
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path
import numpy as np
import psycopg, torch

THESIS = Path(os.environ['THESIS'])
sys.path.insert(0, str(THESIS / 'models'))
from config import ModelConfig  # noqa: E402
from data import _pad  # noqa: E402
from model import TrajectoryMaskedAutoEncoder  # noqa: E402

MAX_LEN, DEV, SPAN = 256, torch.device('cuda' if torch.cuda.is_available() else 'cpu'), 181
ckpt = torch.load(THESIS / 'models' / 'checkpoints' / 'best.pt', map_location=DEV, weights_only=False)
cfg = ckpt['cfg'] if not isinstance(ckpt['cfg'], dict) else ModelConfig(**ckpt['cfg'])
model = TrajectoryMaskedAutoEncoder(cfg).to(DEV)
model.load_state_dict(ckpt['model'], strict=True)
model.eval()

def hav(a, b):
    p = math.pi / 180
    x = math.sin((b[0] - a[0]) * p / 2) ** 2 + math.cos(a[0] * p) * math.cos(b[0] * p) * math.sin((b[1] - a[1]) * p / 2) ** 2
    return 2 * 6371008.8 * math.asin(math.sqrt(x))

with psycopg.connect() as conn:
    conn.execute("SET TimeZone = 'UTC'")
    rows = conn.execute(f"""
      WITH Seqs AS (
        SELECT MMSI, s.Seq FROM Ships, unnest(sequences(Trip)) AS s(Seq)
        WHERE duration(s.Seq) >= interval '{SPAN} minutes' ),
      Picked AS (
        SELECT MMSI, startTimestamp(Seq) AS T0, row_number() OVER (PARTITION BY MMSI ORDER BY startTimestamp(Seq)) AS k
        FROM Seqs )
      SELECT p.MMSI, extract(epoch FROM getTimestamp(i)), ST_Y(valueAtTimestamp(s.TripLonLat, getTimestamp(i))),
             ST_X(valueAtTimestamp(s.TripLonLat, getTimestamp(i))), valueAtTimestamp(s.SOG, getTimestamp(i)),
             valueAtTimestamp(s.COG, getTimestamp(i)), valueAtTimestamp(s.ROT, getTimestamp(i))
      FROM Picked p JOIN Ships s USING (MMSI),
        unnest(instants(tsample(atTime(s.Trip, span(date_bin('1 minute', p.T0, '2000-01-03') + interval '1 minute',
          date_bin('1 minute', p.T0, '2000-01-03') + interval '{SPAN + 1} minutes')), interval '1 minute'))) AS i
      WHERE p.k = 1
      ORDER BY p.MMSI, 2""").fetchall()

tracks = defaultdict(list)
for m, ts, lat, lon, sog, cog, rot in rows:
    tracks[m].append((float(ts), lat, lon, sog, cog, rot))
# keep complete stretches of moving vessels (mean speed of 3 knots or more)
sel = []
for m, t in tracks.items():
    if len(t) != SPAN: continue
    dist = sum(hav((a[1], a[2]), (b[1], b[2])) for a, b in zip(t, t[1:]))
    if dist / (t[-1][0] - t[0][0]) * 1.9438445 >= 3: sel.append(t)
print(len(sel), 'stretches of moving vessels')

def channels(t, masked):
    ts = np.array([r[0] for r in t]); lat = np.array([r[1] for r in t]); lon = np.array([r[2] for r in t])
    vis = np.flatnonzero(~masked)
    lat0, lon0 = lat[vis[0]], lon[vis[0]]
    d = np.stack([lat - lat0, lon - lon0], axis=1); d[masked] = np.nan
    bh = max(np.nanmax(np.abs(d)), 1e-8)
    coords = np.nan_to_num(d / bh).astype(np.float32)
    dt = ts - ts[0]; lm = math.log1p(dt.max())
    loc = [datetime.fromtimestamp(x, timezone.utc) + timedelta(hours=1) for x in ts]
    tau = np.stack([[x.weekday() / 6 for x in loc], [x.hour / 23 for x in loc], [x.minute / 59 for x in loc],
                    np.log1p(dt) / lm], axis=1).astype(np.float32)
    f = lambda k: np.array([r[k] if r[k] is not None else 0.0 for r in t], dtype=np.float32)
    kin = np.stack([np.clip(f(3) / 30, 0, 1), np.clip(f(4) / 180 - 1, -1, 1), np.clip(f(5) / 720, -1, 1)], axis=1).astype(np.float32)
    kin[masked] = 0
    cp, pm = _pad(coords, MAX_LEN)
    return dict(x_spatial=cp, coords=cp, tau=_pad(tau, MAX_LEN)[0], kinematics=_pad(kin, MAX_LEN)[0], pad_mask=pm,
                pos_mask=_pad(masked[:, None], MAX_LEN)[0][:, 0], e_sem=np.zeros((MAX_LEN, cfg.sem_dim), np.float32)), (lat0, lon0, bh)

print('K minutes hidden | stretches | median error model / linear / hermite (m) | mean model / linear / hermite (m) | share hermite better than linear')
for K in (5, 10, 20, 30, 45, 60, 90, 120):
    a = (SPAN - K) // 2; masked = np.zeros(SPAN, bool); masked[a:a + K] = True
    em, el, eh = [], [], []
    for b in range(0, len(sel), 256):
        batch = sel[b:b + 256]
        inputs, params = zip(*(channels(t, masked) for t in batch))
        tt = {k: torch.as_tensor(np.stack([x[k] for x in inputs])).to(DEV) for k in inputs[0]}
        with torch.no_grad():
            out = model(**tt, domain_ids=torch.ones(len(batch), dtype=torch.long, device=DEV),
                        kin_group_masked=False, sem_group_masked=True)
        y = out['pred'][..., :2].cpu().numpy()
        for t, (lat0, lon0, bh), yy in zip(batch, params, y):
            p0, p1 = t[a - 1], t[a + K]
            wm, wl, wh = [], [], []
            for j in range(a, a + K):
                truth = (t[j][1], t[j][2])
                pm = (lat0 + yy[j, 0] * bh, lon0 + yy[j, 1] * bh)
                w = (t[j][0] - p0[0]) / (p1[0] - p0[0])
                pl = (p0[1] + (p1[1] - p0[1]) * w, p0[2] + (p1[2] - p0[2]) * w)
                wm.append(hav(truth, pm)); wl.append(hav(truth, pl))
                # cubic Hermite between the two ends, tangents from the reported SOG (knots) and COG (degrees)
                kx = 111320.0 * math.cos(math.radians(p0[1])); ky = 110540.0
                P0 = np.array([0.0, 0.0]); P1 = np.array([(p1[2] - p0[2]) * kx, (p1[1] - p0[1]) * ky])
                T = p1[0] - p0[0]
                def vel(r):
                    if r[3] is None or r[4] is None: return None
                    v = r[3] / 1.9438445; c = math.radians(r[4]); return np.array([v * math.sin(c), v * math.cos(c)])
                v0, v1 = vel(p0), vel(p1)
                if v0 is None or v1 is None: v0 = v1 = (P1 - P0) / T
                s_ = w; h00 = 2*s_**3 - 3*s_**2 + 1; h10 = s_**3 - 2*s_**2 + s_; h01 = -2*s_**3 + 3*s_**2; h11 = s_**3 - s_**2
                P = h00 * P0 + h10 * T * v0 + h01 * P1 + h11 * T * v1
                ph = (p0[1] + P[1] / ky, p0[2] + P[0] / kx)
                wh.append(hav(truth, ph))
            em.append(st.mean(wm)); el.append(st.mean(wl)); eh.append(st.mean(wh))
    hb = sum(x < y for x, y in zip(eh, el)) / len(eh)
    print(f'{K:4d} | {len(em)} | median model / linear / hermite {st.median(em):6.0f} / {st.median(el):6.0f} / {st.median(eh):6.0f}'
          f' | mean {st.mean(em):6.0f} / {st.mean(el):6.0f} / {st.mean(eh):6.0f} | hermite better than linear {hb:.3f}')
