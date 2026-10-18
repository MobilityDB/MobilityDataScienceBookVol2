"""Export the data of the figures of the nuScenes case study of chapter 4.

Reads the tables that load_nuscenes.sql builds, writes into $OUT the layers and
the spec spec_nuscenes.json of the map figures, which render.sh draws (see
figlib.py), and draws the figures that are not maps with matplotlib.

Usage: python3 export_nuscenes.py
"""
import math
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from figlib import OUT, connect, collection, save, bbox, figure, write_spec, TRACK

plt.rcParams.update({'font.size': 8, 'axes.labelsize': 8,
  'xtick.labelsize': 7, 'ytick.labelsize': 7})
R_EARTH = 6378137.0
# Map origins of the nuScenes global frames (nuscenes-devkit export_poses.py)
ORIGINS = {
    'boston-seaport': (42.336849169438615, -71.05785369873047),
    'singapore-onenorth': (1.2882100868743724, 103.78475189208984),
    'singapore-hollandvillage': (1.2993652317780957, 103.78217697143555),
    'singapore-queenstown': (1.2782562240223188, 103.76741409301758),
}
def local_xform(origin):
    lat0, lon0 = origin
    k = math.cos(math.radians(lat0))
    def conv(c):
        return [lon0 + math.degrees(c[0] / (R_EARTH * k)),
                lat0 + math.degrees(c[1] / R_EARTH)]
    def walk(coords):
        if isinstance(coords[0], (int, float)):
            return conv(coords)
        return [walk(c) for c in coords]
    def xform(g):
        g['coordinates'] = walk(g['coordinates'])
        return g
    return xform

nus = connect('nuscenes')
cur = nus.cursor()
# The ego frame of nuScenes has its origin at the rear axle
EGO = "trgeometry(ST_Force3D(ST_MakeEnvelope(-0.7, -0.87, 3.4, 0.87)), e.Trip)"
GROUPS = [
    ('vehicle', "o.Category LIKE 'vehicle.%%' AND o.Category NOT LIKE 'vehicle.bicycle%%'"
     " AND o.Category NOT LIKE 'vehicle.motorcycle%%'", '255,140,0,170', '120,60,0,255'),
    ('cycle', "o.Category IN ('vehicle.bicycle', 'vehicle.motorcycle')",
     '160,0,200,170', '80,0,100,255'),
    ('pedestrian', "o.Category LIKE 'human.%%'", '220,0,0,200', '110,0,0,255'),
    ('static', "o.Category LIKE 'movable_object.%%'", '120,120,120,150',
     '60,60,60,255'),
]

def scene(name, location):
    xf = local_xform(ORIGINS[location])
    cur.execute("SELECT SceneId FROM Scene WHERE name = %s", (name,))
    sid = cur.fetchone()[0]
    cur.execute("SELECT startTimestamp(Trip) + (endTimestamp(Trip) - "
                "startTimestamp(Trip)) / 2 FROM EgoTrip WHERE SceneId = %s", (sid,))
    tmid = cur.fetchone()[0]
    return sid, tmid, xf

#  scene at one instant: every annotated object and the ego vehicle
print('nus_scene')
sid, tmid, xf = scene('scene-0061', 'singapore-onenorth')
G = "ST_AsGeoJSON(ST_Force2D({}), 6)"
layers, fcs = [], []
ego_path = collection(cur, f"SELECT {G.format('trajectory(tgeompoint(e.Trip))')} "
                      "FROM EgoTrip e WHERE e.SceneId = %s", (sid,), xf)
ego_body = collection(cur, f"SELECT {G.format(f'valueAtTimestamp({EGO}, %s)')} "
                      "FROM EgoTrip e WHERE e.SceneId = %s", (tmid, sid), xf)
paths = collection(cur, f"""SELECT {G.format('trajectory(tgeompoint(o.Trip))')}
  FROM ObjectTrip o WHERE o.SceneId = %s AND length(tgeompoint(o.Trip)) > 2""",
  (sid,), xf)
for gname, cond, fill, stroke in GROUPS:
    fc = collection(cur, f"""SELECT {G.format('valueAtTimestamp(o.Trip, %s)')}
      FROM ObjectTrip o WHERE o.SceneId = %s AND {cond}""", (tmid, sid), xf)
    fcs.append(fc)
    layers.append({'type': 'polygon', 'file': save(f'scene_{gname}', fc),
                   'fill': fill, 'stroke': stroke, 'width': 0.2})
layers = [{'type': 'polygon', 'file': save('scene_ego', ego_body),
           'fill': '0,120,0,220', 'stroke': '0,60,0,255', 'width': 0.25}] + layers
layers += [{'type': 'line', 'file': save('scene_paths', paths),
            'stroke': '90,90,90,255', 'width': 0.25},
           dict(TRACK, file=save('scene_egopath', ego_path), width=0.5)]
figure('nus_scene.pdf', bbox(ego_path, *fcs, pad=0.05, aspect=1.3), layers)

# He ground swept by every object of a parking-lot scene
print('nus_swept')
sid, tmid, xf = scene('scene-0655', 'boston-seaport')
cur.execute("""SELECT o.Category, round((ST_Area(traversedArea(o.Trip, true)) /
  ST_Area(o.Trip::geometry))::numeric, 1) r FROM ObjectTrip o WHERE o.SceneId = %s
  ORDER BY r DESC LIMIT 6""", (sid,))
print('  top ratios', cur.fetchall())
layers, fcs = [], []
for gname, cond, fill, stroke in GROUPS:
    fc = collection(cur, f"""SELECT {G.format('traversedArea(o.Trip, true)')}
      FROM ObjectTrip o WHERE o.SceneId = %s AND {cond}""", (sid,), xf)
    fcs.append(fc)
    layers.append({'type': 'polygon', 'file': save(f'swept_{gname}', fc),
                   'fill': fill.rsplit(',', 1)[0] + ',120', 'stroke': stroke,
                   'width': 0.2})
# The ground swept by the ego vehicle is the union of the ground it sweeps over the pieces of its
# trip of 64 instants each; on its 3,136 poses, the single dissolve of the whole trip takes more
# than ten minutes, the pieces three seconds (on the objects of the scene, the two agree to the
# hundredth of a square meter)
ego_swept = collection(cur, f"""SELECT {G.format(
  'ST_Union(ST_CurveToLine(traversedArea(atTime(e.Trip, sp), true), 64))')}
  FROM (SELECT {EGO} AS Trip FROM EgoTrip e WHERE e.SceneId = %s) e,
  unnest(splitEachNSpans(e.Trip, 64)) sp""", (sid,), xf)
layers.append({'type': 'polygon', 'file': save('swept_ego', ego_swept),
               'fill': '0,120,0,110', 'stroke': '0,60,0,255', 'width': 0.25})
figure('nus_swept.pdf', bbox(ego_swept, *fcs, pad=0.05, aspect=1.6), layers)

# The sensor rig in the body frame of the vehicle
print('nus_rig')
sid = scene('scene-0061', 'singapore-onenorth')[0]
cur.execute("""SELECT se.Channel, cs.X, cs.Y, cs.QW, cs.QX, cs.QY, cs.QZ
  FROM CalibratedSensor cs JOIN Sensor se ON se.SensorId = cs.SensorId
  WHERE cs.CalibratedSensorId IN (SELECT d.CalibratedSensorId FROM SampleData d
  JOIN Sample s ON s.SampleId = d.SampleId WHERE s.SceneId = %s)
  GROUP BY se.Channel, cs.X, cs.Y, cs.QW, cs.QX, cs.QY, cs.QZ ORDER BY se.Channel""", (sid,))
rig = cur.fetchall()

def rotate(q, v):
    w, x, y, z = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
         [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
         [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]]
    return [sum(r[i][j] * v[j] for j in range(3)) for i in range(3)]

def seg_hits_box(p, q, b):
    """Whether the segment pq meets the box b = (x0, y0, x1, y1), tested on 32 points of it"""
    return any(b[0] <= p[0] + (q[0] - p[0]) * t / 32 <= b[2] and
               b[1] <= p[1] + (q[1] - p[1]) * t / 32 <= b[3] for t in range(33))

fig, ax = plt.subplots(figsize=(4.8, 3.0))
BODY = (-0.7, -0.87, 3.4, 0.87)
ax.add_patch(plt.Rectangle(BODY[:2], BODY[2] - BODY[0], BODY[3] - BODY[1], fill=True,
                           fc='#eeeeee', ec='black', lw=0.8))
ax.set_aspect('equal'); ax.set_xlim(-2.8, 5.6); ax.set_ylim(-2.4, 2.4)
ax.set_xlabel('$x$ (m), forward'); ax.set_ylabel('$y$ (m), left')
ax.grid(lw=0.3, alpha=0.5)
ax.plot([0], [0], 'k+', ms=8)
# The arrows first, then each label at the first place around the tip of its arrow whose box meets
# no arrow, no sensor, no edge of the body and no label already placed
arrows, labels = [], []
for ch, x, y, *q in rig:
    look = rotate(q, (0, 0, 1) if ch.startswith('CAM') else (1, 0, 0))
    color = '#1f5fd6' if ch.startswith('CAM') else ('#d62728' if ch.startswith('RADAR')
                                                       else '#2ca02c')
    tip = (x + 0.9 * look[0], y + 0.9 * look[1])
    ax.annotate('', xy=tip, xytext=(x, y), arrowprops=dict(arrowstyle='->', color=color, lw=1.2))
    ax.plot([x], [y], 'o', color=color, ms=3)
    arrows.append(((x, y), tip))
    labels.append((ch.replace('_', ' '), color, tip, math.atan2(look[1], look[0])))
labels.append(('origin', 'black', (0.0, 0.0), -math.pi / 4))
fig.tight_layout()
inv = ax.transData.inverted()
renderer = fig.canvas.get_renderer()
edges = [((BODY[0], BODY[1]), (BODY[2], BODY[1])), ((BODY[2], BODY[1]), (BODY[2], BODY[3])),
         ((BODY[2], BODY[3]), (BODY[0], BODY[3])), ((BODY[0], BODY[3]), (BODY[0], BODY[1]))]
placed = []
for text, color, tip, angle in labels:
    for dist in (0.12, 0.25, 0.4, 0.6):
        for turn in (0, 25, -25, 50, -50, 75, -75, 100, -100, 135, -135, 180):
            a = angle + math.radians(turn)
            ux, uy = math.cos(a), math.sin(a)
            t = ax.text(tip[0] + dist * ux, tip[1] + dist * uy, text, fontsize=6.5, color=color,
                        ha='left' if ux > 0.35 else ('right' if ux < -0.35 else 'center'),
                        va='bottom' if uy > 0.35 else ('top' if uy < -0.35 else 'center'))
            e = t.get_window_extent(renderer).expanded(1.15, 1.5)
            (x0, y0), (x1, y1) = inv.transform([(e.x0, e.y0), (e.x1, e.y1)])
            b = (x0, y0, x1, y1)
            xl, yl = ax.get_xlim(), ax.get_ylim()
            if (x0 >= xl[0] and x1 <= xl[1] and y0 >= yl[0] and y1 <= yl[1]
                    and not any(seg_hits_box(p, r, b) for p, r in arrows + edges)
                    and not any(b[0] <= p[0] <= b[2] and b[1] <= p[1] <= b[3]
                                for p, _ in arrows + [((0.0, 0.0), None)])
                    and not any(b[0] < o[2] and o[0] < b[2] and b[1] < o[3] and o[1] < b[3]
                                for o in placed)):
                placed.append(b)
                break
            t.remove()
        else:
            continue
        break
    else:
        raise SystemExit(f'nus_rig: no free place for the label {text}')
fig.savefig(os.path.join(OUT, 'nus_rig.pdf')); plt.close(fig)
print('  wrote nus_rig.pdf with', len(rig), 'sensors')

# He pitch of the vehicle: stepwise temporal float and slerp values
print('nus_pitch')
cur.execute("""SELECT s.name, maxValue(abs(degrees(pitch(e.Trip)))) m FROM EgoTrip e
  JOIN Scene s USING (SceneId) ORDER BY m DESC LIMIT 1""")
sname, mx = cur.fetchone()
print('  scene with largest pitch', sname, mx)
# The pose is resampled at 1 Hz so that the steps of the temporal float show
K = f"""(SELECT tposeSeq(array_agg(tpose(valueAtTimestamp(e.Trip, t), t) ORDER BY t))
  FROM EgoTrip e JOIN Scene s USING (SceneId), generate_series(startTimestamp(e.Trip),
  endTimestamp(e.Trip), interval '1 second') t WHERE s.name = '{sname}')"""
cur.execute(f"""SELECT extract(epoch FROM getTimestamp(i) - startTimestamp(k)),
  degrees(getValue(i)) FROM (SELECT {K} k) x, unnest(instants(pitch(k))) i ORDER BY 1""")
steps = cur.fetchall()
cur.execute(f"""SELECT extract(epoch FROM t - startTimestamp(k)),
  degrees(pitch(valueAtTimestamp(k, t))) FROM (SELECT {K} k) x,
  generate_series(startTimestamp(k), endTimestamp(k), interval '20 ms') t ORDER BY 1""")
fine = cur.fetchall()
fig, ax = plt.subplots(figsize=(4.8, 2.3))
ax.plot([r[0] for r in fine], [r[1] for r in fine], color='#1f5fd6', lw=0.9,
        label='pitch of the pose interpolated between the samples')
ax.step([r[0] for r in steps], [r[1] for r in steps], where='post', color='#d62728',
        lw=0.9, label='pitch as a temporal float (step)')
ax.set_xlabel('time (s)'); ax.set_ylabel('pitch (degrees)')
ax.legend(fontsize=7, frameon=False, loc='lower left'); ax.grid(lw=0.3, alpha=0.5)
fig.tight_layout(); fig.savefig(os.path.join(OUT, 'nus_pitch.pdf')); plt.close(fig)

# He objects of a scene in the frame of the front camera
print('nus_camera')
sid, tmid, _ = scene('scene-0061', 'singapore-onenorth')
cur.execute("""SELECT o.Category, ST_X(c), ST_Y(c), ST_Z(c) FROM ObjectTrip o, SensorMount s,
  EgoTrip e, LATERAL (SELECT applyPose(point(valueAtTimestamp(tpose(o.Trip), %s)),
  poseInverse(applyPose(s.Mounting, valueAtTimestamp(e.Trip, %s)))) c) x
  WHERE s.Channel = 'CAM_FRONT' AND o.SceneId = e.SceneId AND s.SceneId = e.SceneId
  AND e.SceneId = %s AND valueAtTimestamp(o.Trip, %s) IS NOT NULL""", (tmid, tmid, sid, tmid))
cam = cur.fetchall()
fig, ax = plt.subplots(figsize=(4.8, 3.4))
half = math.radians(35)
ax.fill([0, -60 * math.tan(half), 60 * math.tan(half)], [0, 60, 60], color='#1f5fd6',
        alpha=0.08, lw=0)
colors = {'vehicle': '#ff8c00', 'cycle': '#a000c8', 'pedestrian': '#dc0000',
          'static': '#787878'}
def group(cat):
    if cat.startswith('human'):
        return 'pedestrian'
    if cat in ('vehicle.bicycle', 'vehicle.motorcycle'):
        return 'cycle'
    if cat.startswith('vehicle'):
        return 'vehicle'
    return 'static'
for g in colors:
    pts = [(r[1], r[3]) for r in cam if group(r[0]) == g]
    if pts:
        ax.scatter([p[0] for p in pts], [p[1] for p in pts], s=9, color=colors[g], label=g)
ax.plot([0], [0], 'k^', ms=7)
ax.set_aspect('equal'); ax.set_xlim(-45, 45); ax.set_ylim(-30, 60)
ax.set_xlabel('$x$ (m), to the right of the camera')
ax.set_ylabel('$z$ (m), ahead of the camera')
ax.legend(fontsize=7, frameon=False, loc='upper left', bbox_to_anchor=(1.01, 1.0))
ax.grid(lw=0.3, alpha=0.5)
fig.tight_layout(); fig.savefig(os.path.join(OUT, 'nus_camera.pdf')); plt.close(fig)
print('  objects', len(cam))
nus.close()
write_spec('spec_nuscenes.json')
