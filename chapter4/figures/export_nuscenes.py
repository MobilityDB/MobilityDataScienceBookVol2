#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

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

def seg_point_dist(p, q, c):
    """The distance from the point c to the segment pq"""
    dx, dy = q[0] - p[0], q[1] - p[1]
    t = max(0.0, min(1.0, ((c[0] - p[0]) * dx + (c[1] - p[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(p[0] + t * dx - c[0], p[1] + t * dy - c[1])

def segs_cross(p, q, r, s):
    """Whether the segments pq and rs cross"""
    def side(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (side(p, q, r) * side(p, q, s) < 0) and (side(r, s, p) * side(r, s, q) < 0)

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
# Each label sits at its own arrow, at the tip (or the middle), offset in points and aligned so
# that it extends away from the arrow; a line break keeps a label clear of a neighboring arrow
PLACE = {  # channel: (anchor, dx, dy, ha, va, text)
    'CAM_BACK': ('tip', -3, 0, 'right', 'center', 'CAM BACK'),
    'CAM_BACK_LEFT': ('tip', -2, 2, 'right', 'bottom', 'CAM BACK\nLEFT'),
    'CAM_BACK_RIGHT': ('tip', -2, -2, 'right', 'top', 'CAM BACK\nRIGHT'),
    'CAM_FRONT': ('mid', 0, 3, 'center', 'bottom', 'CAM FRONT'),
    'CAM_FRONT_LEFT': ('tip', -2, 2, 'right', 'bottom', 'CAM\nFRONT\nLEFT'),
    'CAM_FRONT_RIGHT': ('tip', -2, -2, 'right', 'top', 'CAM\nFRONT\nRIGHT'),
    'LIDAR_TOP': ('mid', -3, 0, 'right', 'center', 'LIDAR TOP'),
    'RADAR_BACK_LEFT': ('tip', -3, 0, 'right', 'center', 'RADAR\nBACK LEFT'),
    'RADAR_BACK_RIGHT': ('tip', -3, 0, 'right', 'center', 'RADAR\nBACK RIGHT'),
    'RADAR_FRONT': ('tip', 3, 0, 'left', 'center', 'RADAR\nFRONT'),
    'RADAR_FRONT_LEFT': ('tip', 3, 0, 'left', 'center', 'RADAR\nFRONT LEFT'),
    'RADAR_FRONT_RIGHT': ('tip', 3, 0, 'left', 'center', 'RADAR\nFRONT RIGHT'),
}
# An arrow shows a direction, so its length is free: the lidar's, 0.9 m long, would pass over the
# dot and the arrow of the rear right camera; at 0.38 m it ends 0.12 m from that dot, the clearance
# that the check below requires of every arrow
LENGTH = {'LIDAR_TOP': 0.38}
arrows, texts = {}, {}
for ch, x, y, *q in rig:
    look = rotate(q, (0, 0, 1) if ch.startswith('CAM') else (1, 0, 0))
    color = '#1f5fd6' if ch.startswith('CAM') else ('#d62728' if ch.startswith('RADAR')
                                                       else '#2ca02c')
    tip = (x + LENGTH.get(ch, 0.9) * look[0], y + LENGTH.get(ch, 0.9) * look[1])
    ax.annotate('', xy=tip, xytext=(x, y), arrowprops=dict(arrowstyle='->', color=color, lw=1.2))
    ax.plot([x], [y], 'o', color=color, ms=3)
    arrows[ch] = ((x, y), tip)
    anchor, dx, dy, ha, va, text = PLACE[ch]
    at = tip if anchor == 'tip' else ((x + tip[0]) / 2, (y + tip[1]) / 2)
    texts[ch] = ax.annotate(text, xy=at, xytext=(dx, dy), textcoords='offset points',
                            fontsize=6.5, color=color, ha=ha, va=va, linespacing=1.0)
fig.tight_layout()
# Check: no label meets another sensor's arrow or dot, an edge of the body, another label or the
# frame of the axes
inv = ax.transData.inverted()
renderer = fig.canvas.get_renderer()
edges = [((BODY[0], BODY[1]), (BODY[2], BODY[1])), ((BODY[2], BODY[1]), (BODY[2], BODY[3])),
         ((BODY[2], BODY[3]), (BODY[0], BODY[3])), ((BODY[0], BODY[3]), (BODY[0], BODY[1]))]
boxes = {}
for ch, t in texts.items():
    e = t.get_window_extent(renderer).expanded(1.04, 1.1)
    (x0, y0), (x1, y1) = inv.transform([(e.x0, e.y0), (e.x1, e.y1)])
    boxes[ch] = (x0, y0, x1, y1)
clashes = []
xl, yl = ax.get_xlim(), ax.get_ylim()
for ch, b in boxes.items():
    if b[0] < xl[0] or b[2] > xl[1] or b[1] < yl[0] or b[3] > yl[1]:
        clashes.append(f'{ch} leaves the axes')
    for other, (p, r) in arrows.items():
        if other == ch:  # its own arrow, but for the end the label is anchored at
            a = PLACE[ch][0] == 'tip'
            r = (p[0] + (r[0] - p[0]) * 0.85, p[1] + (r[1] - p[1]) * 0.85) if a else r
            if seg_hits_box(p, r, b) and a:
                clashes.append(f'{ch} meets its own arrow')
        elif seg_hits_box(p, r, b) or (b[0] <= p[0] <= b[2] and b[1] <= p[1] <= b[3]):
            clashes.append(f'{ch} meets the arrow of {other}')
    if any(seg_hits_box(p, r, b) for p, r in edges):
        clashes.append(f'{ch} meets the body')
    for other, o in boxes.items():
        if other < ch and b[0] < o[2] and o[0] < b[2] and b[1] < o[3] and o[1] < b[3]:
            clashes.append(f'{ch} meets the label of {other}')
for ch, (p, r) in arrows.items():  # no arrow crosses another arrow or passes by another dot
    for other, (p2, r2) in arrows.items():
        if other > ch and segs_cross(p, r, p2, r2):
            clashes.append(f'the arrow of {ch} crosses the arrow of {other}')
        if other != ch and seg_point_dist(p, r, p2) < 0.12:
            clashes.append(f'the arrow of {ch} passes by the dot of {other}')
if clashes:
    raise SystemExit('nus_rig: ' + '; '.join(clashes))
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
