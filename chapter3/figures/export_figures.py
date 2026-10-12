"""Export the data of the AIS maps of chapter 3.

- ais_noise_region.png: a deformable moving region, the area of influence of
  the underwater noise of the fishing vessel of the use case (MMSI 219013538)
  as it leaves the harbor of Osterby on January 1, 2025, at five instants. It
  reads the table VesselTrip of the use case (database NOISE_DB, default
  noise).
- ais_hull_turn.png: a fixed-shape moving region, the hull of the ro-ro vessel
  HUMBRIA SEAWAYS (MMSI 219281000) turning by some 150 degrees in the harbor
  of Goteborg on March 1, 2024, at six instants. It reads the table Ships of
  chapter 4 (database AIS_DB, default ais).
- ais_exposure_w.png: the marine strategy area W in the Oresund and the noise
  regions of the 85 vessels heard in it at 02:53:20 on January 1, 2025, those
  sailing faster than 2 knots darker. It reads the table Exposure.
- ais_encounter_sea.png: two vessels sailing from Skagen into the North Sea
  whose noise regions overlap for 18 hours, at 08:00, 14:00, and 20:00.

In the figures of several instants, time runs from light to dark. The helpers are those of
chapter4/figures/figlib.py, the module the chapter 4 figures are drawn with,
#connect included; the timestamps carry their offset, so the time zone of the
session does not change them.

The table Exposure is the one the queries of tcbuffer_case_study.sql create.

Usage: make_figures.sh, which runs it with chapter4/figures on PYTHONPATH and
draws its spec spec_ch3.json with render.sh of chapter 4
"""
from figlib import connect, geo, collection, save, bbox, figure, write_spec, TRACK

def ramp(k, n, light, dark):
    """The color of the k-th of n instants, from light to dark
    @details No sibling: figlib.py styles a layer with one fixed color
    (#HULL, #TRACK), and this ramp is built beside those styles"""
    f = k / max(n - 1, 1)
    return ','.join(str(round(a + f * (b - a))) for a, b in zip(light, dark))

# The deformable region: the noise of the fishing vessel
noise = connect('noise')
cur = noise.cursor()
TRIP = "(SELECT {} FROM VesselTrip WHERE MMSI = 219013538 AND TripId = 1)"
TIMES = ['2025-01-01 22:15:00+00', '2025-01-01 22:30:00+00', '2025-01-01 22:45:00+00',
         '2025-01-01 23:00:00+00', '2025-01-01 23:15:00+00']
print('ais_noise_region')
circles = []
for t in TIMES:
    fc = collection(cur, f"""SELECT {geo(f"ST_CurveToLine(geometry(valueAtTimestamp({TRIP.format('Noise')}, %s)))")},
      round(radius(valueAtTimestamp({TRIP.format('Noise')}, %s))::numeric)""", (t, t))
    circles.append(fc)
    print('  ', t, 'radius', fc['features'][0]['properties'])
track = collection(cur, f"""SELECT {geo(f"trajectory(atTime({TRIP.format('Trip')}, span(timestamptz '{TIMES[0]}', timestamptz '{TIMES[-1]}', true, true)))")}""")
layers = [dict(TRACK, file=save('noise_track', track), width=0.5, stroke='0,0,0,255')]
for k, fc in enumerate(circles):
    layers.append({'type': 'polygon', 'file': save(f'noise_{k}', fc),
                   'fill': ramp(k, len(circles), (190, 230, 190), (20, 110, 40)) + ',90',
                   'stroke': ramp(k, len(circles), (120, 180, 120), (0, 70, 20)) + ',255',
                   'width': 0.4})
figure('ais_noise_region.png', bbox(*circles, pad=0.08, aspect=1.6), layers)
noise.close()

# The fixed-shape region: the hull of the ro-ro vessel
ais = connect('ais')
cur = ais.cursor()
SHIP = "(SELECT Trip FROM Ships WHERE MMSI = 219281000)"
HTIMES = ['2024-03-01 03:15:00+01', '2024-03-01 03:16:15+01', '2024-03-01 03:17:30+01',
          '2024-03-01 03:18:45+01', '2024-03-01 03:20:00+01', '2024-03-01 03:21:00+01']
print('ais_hull_turn')
hulls = []
for t in HTIMES:
    fc = collection(cur, f"SELECT {geo(f'valueAtTimestamp({SHIP}, %s)')}, round(degrees(valueAtTimestamp(yaw({SHIP}), %s))::numeric)", (t, t))
    hulls.append(fc)
    print('  ', t, 'yaw', fc['features'][0]['properties'])
htrack = collection(cur, f"""SELECT {geo(f"trajectory(atTime(tgeompoint({SHIP}), span(timestamptz '{HTIMES[0]}', timestamptz '{HTIMES[-1]}', true, true)))")}""")
hlayers = [dict(TRACK, file=save('hull_track', htrack), width=0.4)]
for k, fc in enumerate(hulls):
    hlayers.append({'type': 'polygon', 'file': save(f'hull_{k}', fc),
                    'fill': ramp(k, len(hulls), (255, 215, 160), (200, 90, 0)) + ',200',
                    'stroke': '120,60,0,255', 'width': 0.25})
figure('ais_hull_turn.png', bbox(*hulls, htrack, pad=0.15, aspect=1.6), hlayers)
ais.close()
write_spec('spec_ch3.json')

# ---------------------------------------------------------------------------
# The exposure of a protected area: the marine strategy area W, in the
# Oresund, at 02:53:20 on January 1, 2025, when the noise of 85 vessels
# reaches it; the vessels sailing faster than 2 knots are drawn darker
# ---------------------------------------------------------------------------
noise = connect('noise')
cur = noise.cursor()
T_W = '2025-01-01 02:53:20+00'
HEARD = f"""(SELECT DISTINCT e.MMSI, e.TripId FROM Exposure e
  WHERE e.AreaId = 122 AND e.Heard @> timestamptz '{T_W}')"""
print('ais_exposure_w')
area_w = collection(cur, f"SELECT {geo('Geom')} FROM NaturalAreas WHERE Id = 122")
heard_sailing = collection(cur, f"""SELECT {geo(f"ST_CurveToLine(geometry(valueAtTimestamp(v.Noise, timestamptz '{T_W}')))")}
  FROM VesselTrip v JOIN {HEARD} h USING (MMSI, TripId)
  WHERE valueAtTimestamp(v.Speed, timestamptz '{T_W}') > 2""")
heard_rest = collection(cur, f"""SELECT {geo(f"ST_CurveToLine(geometry(valueAtTimestamp(v.Noise, timestamptz '{T_W}')))")}
  FROM VesselTrip v JOIN {HEARD} h USING (MMSI, TripId)
  WHERE valueAtTimestamp(v.Speed, timestamptz '{T_W}') <= 2""")
print('   heard', len(heard_sailing['features']) + len(heard_rest['features']),
      'sailing', len(heard_sailing['features']))
figure('ais_exposure_w.png', bbox(area_w, pad=0.08, aspect=1.0), [
    {'type': 'polygon', 'file': save('w_sailing', heard_sailing), 'fill': '20,110,40,80',
     'stroke': '0,70,20,255', 'width': 0.3},
    {'type': 'polygon', 'file': save('w_rest', heard_rest), 'fill': '150,210,150,120',
     'stroke': '60,140,60,255', 'width': 0.2},
    {'type': 'polygon', 'file': save('w_area', area_w), 'fill': '160,90,40,40',
     'stroke': '120,60,20,255', 'width': 0.5}])

# ---------------------------------------------------------------------------
# An acoustic encounter at sea: two vessels sailing west from Skagen 8 to 20
# km apart, whose noise regions overlap for 18 hours, at 08:00, 14:00 and
# 20:00
# ---------------------------------------------------------------------------
print('ais_encounter_sea')
PAIR = (352002271, 636018854)
ETIMES = ['2025-01-01 08:00:00+00', '2025-01-01 14:00:00+00', '2025-01-01 20:00:00+00']
elayers, efcs = [], []
for m, (light, dark) in zip(PAIR, (((190, 230, 190), (20, 110, 40)), ((200, 200, 240), (40, 40, 160)))):
    track = collection(cur, f"""SELECT {geo(f"trajectory(atTime(Trip, span(timestamptz '{ETIMES[0]}', timestamptz '{ETIMES[-1]}', true, true)))")}
      FROM VesselTrip WHERE MMSI = {m}""")
    elayers.append(dict(TRACK, file=save(f'enc_track_{m}', track), width=0.4,
                        stroke=ramp(1, 1, light, dark) + ',255'))
    for k, t in enumerate(ETIMES):
        fc = collection(cur, f"""SELECT {geo(f"ST_CurveToLine(geometry(valueAtTimestamp(Noise, timestamptz '{t}')))")}
          FROM VesselTrip WHERE MMSI = {m}""")
        efcs.append(fc)
        elayers.append({'type': 'polygon', 'file': save(f'enc_{m}_{k}', fc),
                        'fill': ramp(k, len(ETIMES), light, dark) + ',70',
                        'stroke': ramp(k, len(ETIMES), light, dark) + ',255', 'width': 0.35})
figure('ais_encounter_sea.png', bbox(*efcs, pad=0.05, aspect=1.6), elayers)
noise.close()
write_spec('spec_ch3.json')
