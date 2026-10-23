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

"""Export the data of the map figures of the AIS case study of chapter 4.

Reads the tables ShipsRigid, ShipShape and AISCleanPoly that ais_poses.sql
builds from the table AISClean of the AIS database of the book (January 20,
2026), and writes into $OUT the layers and
the spec spec_ais.json of the figures, which render.sh draws (see figlib.py).

Usage: python3 export_ais.py
"""
from figlib import (connect, geo, collection, save, bbox, figure, write_spec,
                    HULL, SWEPT, TRACK, RED_HULL)

ais = connect('ais')
cur = ais.cursor()

def window(mmsi, t1, t2):
    return (f"(SELECT atTime(Trip, tstzspan '[{t1}, {t2}]') FROM ShipsRigid "
            f"WHERE MMSI = {mmsi})")

# A ferry turning in the port of Gedser: placements, swept area,
# and the paths of the antenna, the bow, and the stern
print('ais_turn')
W = window(219423000, '2026-01-20 05:42:30', '2026-01-20 05:52:00')
cur.execute(f"SELECT numInstants({W}), round(degrees(minValue(yaw({W})))::numeric,1),"
            f" round(degrees(maxValue(yaw({W})))::numeric,1)")
print('  instants, yaw range', cur.fetchone())
hulls = collection(cur, f"""SELECT {geo(f'valueAtTimestamp({W}, t)')},
  to_char(t, 'HH24:MI') FROM generate_series(timestamptz '2026-01-20 05:42:30',
  timestamptz '2026-01-20 05:52:00', interval '30 seconds') t""")
swept = collection(cur, f"SELECT {geo(f'traversedArea({W}, true)')}")
cur.execute(f"SELECT ST_Area(traversedArea({W}, true))")
print('  swept area m2', cur.fetchone())
track = collection(cur, f"SELECT {geo(f'trajectory(tgeompoint({W}))')}")
bow = collection(cur, f"""SELECT {geo('ST_MakeLine(p ORDER BY t)')} FROM (SELECT
  getValue(i) p, getTimestamp(i) t FROM ShipShape s, unnest(instants(bodyPointTrajectory({W},
  ST_PointN(ST_ExteriorRing(s.Footprint), 3)))) i WHERE s.MMSI = 219423000) x""")
stern = collection(cur, f"""SELECT {geo('ST_MakeLine(p ORDER BY t)')} FROM (SELECT
  getValue(i) p, getTimestamp(i) t FROM ShipShape s, unnest(instants(bodyPointTrajectory({W},
  ST_LineInterpolatePoint(ST_MakeLine(ST_PointN(ST_ExteriorRing(s.Footprint), 1),
  ST_PointN(ST_ExteriorRing(s.Footprint), 5)), 0.5)))) i WHERE s.MMSI = 219423000) x""")
ext = bbox(swept, hulls, pad=0.06, aspect=0.8)
f_h, f_s, f_t = save('turn_hulls', hulls), save('turn_swept', swept), save('turn_track', track)
f_b, f_st = save('turn_bow', bow), save('turn_stern', stern)
figure('ais_turn_swept.pdf', ext, [dict(TRACK, file=f_t), dict(HULL, file=f_h),
       dict(SWEPT, file=f_s)])
figure('ais_turn_paths.pdf', ext, [
    dict(TRACK, file=f_t, width=0.7),
    {'type': 'line', 'file': f_b, 'stroke': '220,0,0,255', 'width': 0.7},
    {'type': 'line', 'file': f_st, 'stroke': '0,150,0,255', 'width': 0.7}])

# The heading of a double-ended ferry flips at the berth: TYCHO BRAHE in Helsingor, at the flip
# of the figure, between the records of 1:33:57 and 1:34:27
print('ais_flip')
cur.execute("""WITH d AS (SELECT T, Heading, SOG, LAG(T) OVER w pt,
  LAG(Heading) OVER w ph FROM AISCleanPoly WHERE MMSI = 219230000
  WINDOW w AS (ORDER BY T))
  SELECT pt, T, ph, Heading, SOG FROM d
  WHERE LEAST(abs(Heading - ph), 360 - abs(Heading - ph)) > 90
    AND pt = timestamp '2026-01-20 01:33:57'""")
pt, nt, ph, nh, sog = cur.fetchone()
print('  flip', pt, nt, ph, nh, sog)
t1 = (pt - (nt - pt)).strftime('%Y-%m-%d %H:%M:%S')
t2 = (nt + (nt - pt)).strftime('%Y-%m-%d %H:%M:%S')
W = window(219230000, t1, t2)
step = (nt - pt).total_seconds() / 8
hulls = collection(cur, f"""SELECT {geo(f'valueAtTimestamp({W}, t)')}
  FROM generate_series(timestamptz '{pt}', timestamptz '{nt}',
  interval '{step} seconds') t""")
swept = collection(cur, f"SELECT {geo(f'traversedArea({W}, true)')}")
ext = bbox(swept, pad=0.6, aspect=1.4)
figure('ais_flip.pdf', ext, [dict(HULL, file=save('flip_hulls', hulls),
       fill='255,140,0,90'), dict(SWEPT, file=save('flip_swept', swept))])

# Two ferries crossing the Oresund: hulls against antennas
print('ais_encounter')
S = "tstzspan '[2026-01-20 02:13:00, 2026-01-20 02:25:00]'"
cur.execute(f"""WITH w AS (SELECT (SELECT atTime(Trip, {S}) FROM ShipsRigid WHERE MMSI = 219230000) a,
  (SELECT atTime(Trip, {S}) FROM ShipsRigid WHERE MMSI = 265041000) b)
  SELECT getTimestamp(nearestApproachInstant(a, b)), a |=| b,
  getTimestamp(nearestApproachInstant(tgeompoint(a), tgeompoint(b))),
  tgeompoint(a) |=| tgeompoint(b) FROM w""")
th, dh, tp, dp = cur.fetchone()
print('  hull NAD', th, dh, ' antenna NAD', tp, dp)
WA = f"(SELECT atTime(Trip, {S}) FROM ShipsRigid WHERE MMSI = 219230000)"
WB = f"(SELECT atTime(Trip, {S}) FROM ShipsRigid WHERE MMSI = 265041000)"
ha = collection(cur, f"SELECT {geo(f'valueAtTimestamp({WA}, %s)')}", (th,))
hb = collection(cur, f"SELECT {geo(f'valueAtTimestamp({WB}, %s)')}", (th,))
hull_line = collection(cur, f"""SELECT {geo(f'''ST_ShortestLine(valueAtTimestamp({WA}, %s),
  valueAtTimestamp({WB}, %s))''')}""", (th, th))
ant_line = collection(cur, f"""SELECT {geo(f'''ST_MakeLine(valueAtTimestamp(tgeompoint({WA}), %s),
  valueAtTimestamp(tgeompoint({WB}), %s))''')}""", (th, th))
ants = collection(cur, f"""SELECT {geo(f'valueAtTimestamp(tgeompoint(w), %s)')}
  FROM (VALUES ({WA}), ({WB})) v(w)""", (th,))
tracks = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(w))')}
  FROM (VALUES ({WA}), ({WB})) v(w)""")
past = collection(cur, f"""SELECT {geo('valueAtTimestamp(w, t)')}
  FROM (VALUES ({WA}), ({WB})) v(w), generate_series(timestamptz '2026-01-20 02:13:00',
  timestamptz '2026-01-20 02:25:00', interval '2 minutes') t""")
f_ha, f_hb = save('enc_hull_a', ha), save('enc_hull_b', hb)
f_hl, f_al = save('enc_hull_line', hull_line), save('enc_ant_line', ant_line)
f_an, f_tr, f_pa = save('enc_ants', ants), save('enc_tracks', tracks), save('enc_past', past)
figure('ais_encounter_context.pdf', bbox(tracks, pad=0.08, aspect=1.5), [
    dict(HULL, file=f_ha), dict(HULL, file=f_hb),
    dict(HULL, file=f_pa, fill='255,140,0,60', stroke='120,60,0,120'),
    dict(TRACK, file=f_tr)])
figure('ais_encounter_zoom.pdf', bbox(ha, hb, pad=0.25, aspect=1.5), [
    {'type': 'point', 'file': f_an, 'fill': '0,0,0,255', 'size': 1.6},
    {'type': 'line', 'file': f_al, 'stroke': '0,0,255,255', 'width': 0.6,
     'style': 'dash'},
    {'type': 'line', 'file': f_hl, 'stroke': '220,0,0,255', 'width': 0.8},
    dict(HULL, file=f_ha), dict(HULL, file=f_hb), dict(TRACK, file=f_tr,
    width=0.4)])

# A trawler whose heading differs from its course
print('ais_crab')
W = window(211364330, '2026-01-20 07:14:53', '2026-01-20 07:17:29')
T = ("generate_series(timestamptz '2026-01-20 07:14:53', "
     "timestamptz '2026-01-20 07:17:29', interval '30 seconds') t")
hulls = collection(cur, f"SELECT {geo(f'valueAtTimestamp({W}, t)')} FROM {T}")
heading = collection(cur, f"""SELECT {geo('''ST_MakeLine(p, ST_Translate(p,
  60 * cos(y), 60 * sin(y)))''')} FROM (SELECT valueAtTimestamp(tgeompoint({W}), t) p,
  valueAtTimestamp(yaw({W}), t) y FROM {T}) x""")
course = collection(cur, f"""SELECT {geo('''ST_MakeLine(p, ST_Translate(p,
  60 * sin(a), 60 * cos(a)))''')} FROM (SELECT valueAtTimestamp(tgeompoint({W}), t) p,
  valueAtTimestamp(azimuth(tgeompoint({W})), t) a FROM {T}) x""")
track = collection(cur, f"SELECT {geo(f'trajectory(tgeompoint({W}))')}")
figure('ais_crab.pdf', bbox(track, hulls, pad=0.15, aspect=1.4), [
    {'type': 'line', 'file': save('crab_heading', heading), 'stroke': '220,0,0,255',
     'width': 0.7},
    {'type': 'line', 'file': save('crab_course', course), 'stroke': '0,150,0,255',
     'width': 0.7},
    dict(HULL, file=save('crab_hulls', hulls)),
    dict(TRACK, file=save('crab_track', track), width=0.4)])
# ---------------------------------------------------------------------------
# The two layers of the text, the vessels as temporal points (a) and as
# temporal rigid geometries (b), in the port of Frederikshavn at one instant
# ---------------------------------------------------------------------------
print('ais_layers')
PORT = "ST_Transform(ST_Point(10.55, 57.44, 4326), 25832)"
T0 = "timestamptz '2026-01-20 10:00:00'"
NEAR = f"WHERE ST_DWithin(valueAtTimestamp(tgeompoint(Trip), {T0}), {PORT}, 1500)"
layer_points = collection(cur, f"SELECT {geo(f'valueAtTimestamp(tgeompoint(Trip), {T0})')}, MMSI FROM ShipsRigid {NEAR}")
layer_hulls = collection(cur, f"SELECT {geo(f'valueAtTimestamp(Trip, {T0})')}, MMSI FROM ShipsRigid {NEAR}")
lext = bbox(layer_hulls, pad=0.08, aspect=1.0)
figure('ais_layer_points.pdf', lext, [
    {'type': 'point', 'file': save('layer_points', layer_points), 'fill': '220,0,0,255',
     'size': 3.5}])
figure('ais_layer_hulls.pdf', lext, [dict(RED_HULL, file=save('layer_hulls', layer_hulls))])

# ---------------------------------------------------------------------------
# The reference geometries of the Anholt offshore wind farm, derived from its
# 111 turbines (table Turbines, loaded by load_turbines.sql from
# OpenStreetMap): its location A, the centroid of the turbines, and its extent,
# as the convex hull B and as the concave hull C of the turbines, with the
# vessel traffic of the day that passes within 10 km of B. The crew-transfer
# vessels of the farm (type HSC), which sail among the turbines, are drawn in
# red
# ---------------------------------------------------------------------------
print('ais_windfarm')
TURBINES = "(SELECT ST_Collect(Geom) FROM Turbines)"
WF_A = f"ST_Centroid({TURBINES})"
WF_B = f"ST_ConvexHull({TURBINES})"
WF_C = f"ST_ConcaveHull({TURBINES}, 0.3)"
cur.execute(f"""SELECT (SELECT count(*) FROM Turbines), round(ST_Area({WF_B}) / 1e6, 1),
  ST_NPoints({WF_B}) - 1, round(ST_Area({WF_C}) / 1e6, 1), ST_NPoints({WF_C}) - 1""")
print('  turbines, B km2 and vertices, C km2 and vertices', cur.fetchone())
NEAR = f"eDwithin(tgeompoint(Trip), {WF_B}, 10000)"
SERVICE = """MMSI IN (SELECT MMSI FROM AISCleanPoly WHERE ShipType = 'HSC')"""
wf_turbines = collection(cur, f"SELECT {geo('Geom')} FROM Turbines")
wf_a = collection(cur, f"SELECT {geo(WF_A)}")
wf_b = collection(cur, f"SELECT {geo(WF_B)}")
wf_c = collection(cur, f"SELECT {geo(WF_C)}")
wf_traffic = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(Trip))')}, MMSI
  FROM ShipsRigid WHERE {NEAR} AND NOT {SERVICE}""")
wf_service = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(Trip))')}, MMSI
  FROM ShipsRigid WHERE {NEAR} AND {SERVICE}""")
print('  vessels within 10 km of B', len(wf_traffic['features']) + len(wf_service['features']),
      'of which service vessels', len(wf_service['features']))
figure('ais_windfarm.pdf', bbox(wf_b, pad=0.25, aspect=1.4), [
    {'type': 'point', 'file': save('wf_a', wf_a), 'fill': '255,230,0,255', 'size': 2.6},
    {'type': 'point', 'file': save('wf_turbines', wf_turbines), 'fill': '40,40,40,255',
     'stroke': '40,40,40,255', 'size': 0.9},
    dict(TRACK, file=save('wf_service', wf_service), width=0.35, stroke='220,0,0,220'),
    {'type': 'polygon', 'file': save('wf_c', wf_c), 'fill': '220,0,0,60',
     'stroke': '160,0,0,255', 'width': 0.45},
    {'type': 'polygon', 'file': save('wf_b', wf_b), 'fill': '30,60,220,50',
     'stroke': '0,0,160,255', 'width': 0.45},
    dict(TRACK, file=save('wf_traffic', wf_traffic), width=0.3, stroke='0,0,160,170')])

# ---------------------------------------------------------------------------
# A vessel arriving at the docks: SANTA MARTA EXPRESS turns at the entrance of
# its basin in the port of Aarhus and moves into its berth
# ---------------------------------------------------------------------------
print('ais_dock')
DOCK = ("(SELECT atTime(Trip, tstzspan '[2026-01-20 08:10:00, "
        "2026-01-20 08:37:00]') FROM ShipsRigid WHERE MMSI = 636024484)")
cur.execute(f"SELECT ST_Area(traversedArea({DOCK}, true)), numInstants({DOCK})")
print('  swept m2, instants', cur.fetchone())
dock_swept = collection(cur, f"SELECT {geo(f'traversedArea({DOCK}, true)')}")
dock_hulls = collection(cur, f"""SELECT {geo(f'valueAtTimestamp({DOCK}, t)')},
  to_char(t, 'HH24:MI') FROM generate_series(timestamptz '2026-01-20 08:10:00',
  timestamptz '2026-01-20 08:37:00', interval '3 minutes') t""")
dock_track = collection(cur, f"SELECT {geo(f'trajectory(tgeompoint({DOCK}))')}")
# the map keeps the proportions of the swept area, so that at 0.85\textwidth it is
# less than a third of the text height
figure('ais_dock.pdf', bbox(dock_swept, pad=0.12), [
    dict(TRACK, file=save('dock_track', dock_track), width=0.5),
    dict(HULL, file=save('dock_hulls', dock_hulls)),
    dict(SWEPT, file=save('dock_swept', dock_swept))])

# ---------------------------------------------------------------------------
# The end of the breakwater at the entrance of the port of Helsingborg: (a) the
# trajectories of the vessels whose antenna passed within 600 m of it, and (b)
# the vessel that came closest to it according to the antennas and according
# to the hulls, each at its closest approach, with its trajectory
# ---------------------------------------------------------------------------
print('helsingborg')
BW = "geometry 'SRID=25832;Point(729493 6216766)'"
cur.execute(f"SELECT MMSI, Trip |=| {BW} FROM ShipsRigid ORDER BY 2 LIMIT 1")
hull_mmsi, hull_dist = cur.fetchone()
cur.execute(f"SELECT MMSI, tgeompoint(Trip) |=| {BW} FROM ShipsRigid ORDER BY 2 LIMIT 1")
ant_mmsi, ant_dist = cur.fetchone()
print('  closest hull', hull_mmsi, hull_dist, ' closest antenna', ant_mmsi, ant_dist)
HULL_T = f"getTimestamp(nearestApproachInstant(Trip, {BW}))"
ANT_T = f"getTimestamp(nearestApproachInstant(tgeompoint(Trip), {BW}))"
bw = collection(cur, f"SELECT {geo(BW)}")
bw_tracks = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(Trip))')}, MMSI
  FROM ShipsRigid WHERE eDwithin(tgeompoint(Trip), {BW}, 600)""")
hull_win = collection(cur, f"""SELECT {geo(f'valueAtTimestamp(Trip, {HULL_T})')}, {HULL_T}
  FROM ShipsRigid WHERE MMSI = %s""", (hull_mmsi,))
hull_track = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(Trip))')}
  FROM ShipsRigid WHERE MMSI = %s""", (hull_mmsi,))
ant_win = collection(cur, f"""SELECT {geo(f'valueAtTimestamp(tgeompoint(Trip), {ANT_T})')},
  {ANT_T} FROM ShipsRigid WHERE MMSI = %s""", (ant_mmsi,))
ant_track = collection(cur, f"""SELECT {geo('trajectory(tgeompoint(Trip))')}
  FROM ShipsRigid WHERE MMSI = %s""", (ant_mmsi,))
# Panel (a) spans 700 m around the breakwater, panel (b) the breakwater and the
# two vessels at their closest approach
ext_a = collection(cur, f"SELECT {geo(f'ST_Expand({BW}, 350, 270)')}")
BW_POINT = {'type': 'point', 'file': save('bw', bw), 'fill': '227,26,28,255', 'size': 2.2}
figure('helsingborg_1.pdf', bbox(ext_a, pad=0, aspect=1400 / 1080), [
    BW_POINT, dict(TRACK, file=save('bw_tracks', bw_tracks), width=0.25)], width=1400)
figure('helsingborg_2.pdf', bbox(bw, ant_win, hull_win, pad=0.2, aspect=1400 / 1080), [
    BW_POINT,
    {'type': 'point', 'file': save('bw_ant_win', ant_win), 'fill': '0,0,255,255', 'size': 2.2},
    {'type': 'polygon', 'file': save('bw_hull_win', hull_win), 'fill': '51,160,44,255',
     'stroke': '0,0,0,255', 'width': 0.2},
    dict(TRACK, file=save('bw_ant_track', ant_track), width=0.3),
    dict(TRACK, file=save('bw_hull_track', hull_track), width=0.3, stroke='51,160,44,255')],
    width=1400)

ais.close()
write_spec('spec_ais.json')
