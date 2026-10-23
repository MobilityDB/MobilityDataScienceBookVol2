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

"""Export the layers and the QGIS jobs of the four maps of the figure of the Hermite curve of chapter
11: one GeoPackage and one job job_<panel>.json per panel, which render.sh of chapter 5
(../../chapter5/figures/render.sh) draws with render_map.py. For each panel, the hidden interval
[ta, tb] is filled in two ways from the trip of Ships alone: the straight segment between the
positions at ta and tb (the baseline linear), and the cubic Hermite curve whose tangents at ta and tb
are the reported speed (SOG) along the reported course (COG), the course turned into a grid direction
of EPSG:25832 by projecting the point 1 km along it on the ellipsoid. The panels gap4907 and gap7902
are real gaps of the use case, drawn with the reconstruction of the model crossdomain; the panels
turn209276000 and turn210620000 hide 12 observed minutes around a turn, whose true path is exported
as the layer truth, and both fills are scored at the hidden minutes. summary.json holds, per panel,
the hidden interval, its length and duration, the speed and course at its ends, the ship type, the
errors or the largest separation of the two fills, and the extent of the map.

    OUT=<directory> python3 export_hermite.py

The database is the one named by the PostgreSQL environment variables (PGDATABASE, PGHOST, ...); the
files are written to $OUT (default: the working directory).
"""
import json, os, subprocess

PG = "PG:dbname=" + os.environ.get("PGDATABASE", os.environ.get("USER", "")) + "".join(
    f" {k}={os.environ[v]}" for k, v in (("host", "PGHOST"), ("port", "PGPORT"), ("user", "PGUSER")) if os.environ.get(v))
PSQL = ["psql", "-X", "-At", "-F", "|"]
OUT = os.path.abspath(os.environ.get("OUT", "."))
os.makedirs(OUT, exist_ok=True)
os.environ["PGTZ"] = "UTC"

# panel: (name, MMSI, ta, tb, synthetic, GapId of the real gap or None)
PANELS = [
    ("gap4907", 246878000, None, None, False, 4907),
    ("gap7902", 566141000, None, None, False, 7902),
    ("turn209276000", 209276000, "2026-01-20 14:46:00+00", "2026-01-20 14:58:00+00", True, None),
    ("turn210620000", 210620000, "2026-01-20 00:17:00+00", "2026-01-20 00:29:00+00", True, None),
]
PX = (700, 560)          # panel image in pixels at 300 dpi: 0.49 \textwidth x about 1.9 in
CONTEXT = "6 minutes"    # track drawn before and after the hidden interval

def psql(sql):
    return subprocess.run(PSQL + ["-c", "SET TimeZone = 'UTC'", "-c", sql], capture_output=True, text=True, check=True).stdout.strip().splitlines()[-1]

def ends(m, ta, tb, gap):
    if gap is not None:
        return psql(f"SELECT TStart, TEnd FROM Gaps WHERE GapId = {gap}").split("|")
    return ta, tb

# The Hermite curve between ta and tb, sampled every 10 s (Curve) or at the whole minutes (Minutes)
def hermite_sql(m, ta, tb, step):
    return f"""
    WITH E AS (
      SELECT valueAtTimestamp(Trip, '{ta}'::timestamptz) AS pa, valueAtTimestamp(Trip, '{tb}'::timestamptz) AS pb,
        extract(epoch FROM '{tb}'::timestamptz - '{ta}'::timestamptz) AS Dur,
        valueAtTimestamp(SOG, '{ta}'::timestamptz) * 1852 / 3600.0 AS va,
        valueAtTimestamp(SOG, '{tb}'::timestamptz) * 1852 / 3600.0 AS vb,
        valueAtTimestamp(COG, '{ta}'::timestamptz) AS ca, valueAtTimestamp(COG, '{tb}'::timestamptz) AS cb
      FROM Ships WHERE MMSI = {m} ),
    D AS (  -- the course of each end as a direction of the grid of EPSG:25832
      SELECT *, ST_Azimuth(pa, ST_Transform(ST_Project(ST_Transform(pa, 4326)::geography, 1000, radians(ca))::geometry, 25832)) AS aa,
                ST_Azimuth(pb, ST_Transform(ST_Project(ST_Transform(pb, 4326)::geography, 1000, radians(cb))::geometry, 25832)) AS ab
      FROM E ),
    S AS (
      SELECT t, extract(epoch FROM t - '{ta}'::timestamptz) / D.Dur AS s, D.*
      FROM D, generate_series('{ta}'::timestamptz, '{tb}'::timestamptz, interval '{step}') AS t )
    SELECT t,
      ST_SetSRID(ST_MakePoint(
        (2*s^3 - 3*s^2 + 1) * ST_X(pa) + (s^3 - 2*s^2 + s) * Dur * va * sin(aa) + (-2*s^3 + 3*s^2) * ST_X(pb) + (s^3 - s^2) * Dur * vb * sin(ab),
        (2*s^3 - 3*s^2 + 1) * ST_Y(pa) + (s^3 - 2*s^2 + s) * Dur * va * cos(aa) + (-2*s^3 + 3*s^2) * ST_Y(pb) + (s^3 - s^2) * Dur * vb * cos(ab)),
        25832) AS geom,
      ST_LineInterpolatePoint(ST_MakeLine(pa, pb), s) AS lin
    FROM S"""

def ogr(path, layer, gtype, sql):
    subprocess.run(["ogr2ogr", "-f", "GPKG", "-a_srs", "EPSG:25832", "-nlt", gtype, path, PG, "-nln", layer,
                    "-update", "-overwrite", "-sql", sql], check=True, capture_output=True)

summary = {}
for name, m, ta, tb, synthetic, gap in PANELS:
    ta, tb = ends(m, ta, tb, gap)
    g = f"{OUT}/{name}.gpkg"
    if os.path.exists(g): os.remove(g)
    W = f"span('{ta}'::timestamptz - interval '{CONTEXT}', '{tb}'::timestamptz + interval '{CONTEXT}')"
    H = f"span('{ta}'::timestamptz, '{tb}'::timestamptz)"
    # observed track around the hidden interval, without it
    ogr(g, "track", "MULTILINESTRING", f"""SELECT ST_Multi(trajectory(minusTime(atTime(Trip, {W}), {H}))) AS geom
        FROM Ships WHERE MMSI = {m}""")
    ogr(g, "reports", "POINT", f"""SELECT c.Geom AS geom FROM AISClean c
        WHERE c.MMSI = {m} AND (c.T AT TIME ZONE 'UTC') <@ {W} AND NOT (c.T AT TIME ZONE 'UTC') <@ {H}""")
    if synthetic:
        ogr(g, "truth", "LINESTRING", f"SELECT trajectory(atTime(Trip, {H})) AS geom FROM Ships WHERE MMSI = {m}")
    ogr(g, "straight", "LINESTRING", f"""SELECT ST_MakeLine(valueAtTimestamp(Trip, '{ta}'::timestamptz),
        valueAtTimestamp(Trip, '{tb}'::timestamptz)) AS geom FROM Ships WHERE MMSI = {m}""")
    ogr(g, "curve", "LINESTRING", f"SELECT ST_MakeLine(geom ORDER BY t) AS geom FROM ({hermite_sql(m, ta, tb, '10 seconds')}) h")
    ogr(g, "curve_min", "POINT", f"SELECT geom FROM ({hermite_sql(m, ta, tb, '1 minute')}) h WHERE t > '{ta}' AND t < '{tb}'")
    ogr(g, "straight_min", "POINT", f"SELECT lin AS geom FROM ({hermite_sql(m, ta, tb, '1 minute')}) h WHERE t > '{ta}' AND t < '{tb}'")
    ogr(g, "ends", "POINT", f"""SELECT valueAtTimestamp(Trip, t) AS geom FROM Ships, unnest(ARRAY['{ta}'::timestamptz, '{tb}'::timestamptz]) AS t
        WHERE MMSI = {m}""")
    if gap is not None:
        ogr(g, "model", "POINT", f"SELECT Geom AS geom FROM Reconstructed WHERE GapId = {gap} AND Task = 'gap' AND Model = 'crossdomain'")
    info = {"ta": ta, "tb": tb}
    if synthetic:
        r = psql(f"""SELECT round(avg(ST_Distance(h.lin, valueAtTimestamp(s.Trip, h.t)))), round(avg(ST_Distance(h.geom, valueAtTimestamp(s.Trip, h.t)))),
              round(max(ST_Distance(h.lin, valueAtTimestamp(s.Trip, h.t)))), round(max(ST_Distance(h.geom, valueAtTimestamp(s.Trip, h.t))))
            FROM ({hermite_sql(m, ta, tb, '1 minute')}) h, Ships s WHERE s.MMSI = {m} AND h.t > '{ta}' AND h.t < '{tb}'""").split("|")
        info.update(mean_line=r[0], mean_curve=r[1], max_line=r[2], max_curve=r[3])
    else:
        r = psql(f"""SELECT round(max(ST_Distance(h.lin, h.geom))) FROM ({hermite_sql(m, ta, tb, '10 seconds')}) h""")
        info.update(max_sep=r)
    info.update(dict(zip(("mins", "dist", "sa", "sb", "ca", "cb", "type"), psql(f"""
        SELECT round(extract(epoch FROM '{tb}'::timestamptz - '{ta}'::timestamptz) / 60, 1),
          round(ST_Distance(valueAtTimestamp(Trip, '{ta}'::timestamptz), valueAtTimestamp(Trip, '{tb}'::timestamptz))),
          round(valueAtTimestamp(SOG, '{ta}'::timestamptz)::numeric, 1), round(valueAtTimestamp(SOG, '{tb}'::timestamptz)::numeric, 1),
          round(valueAtTimestamp(COG, '{ta}'::timestamptz)::numeric), round(valueAtTimestamp(COG, '{tb}'::timestamptz)::numeric),
          (SELECT ShipType FROM Vessels WHERE MMSI = {m})
        FROM Ships WHERE MMSI = {m}""").split("|"))))
    # extent: the window's track and fills, padded, with the aspect of the panel
    b = psql(f"""SELECT ST_XMin(e), ST_YMin(e), ST_XMax(e), ST_YMax(e) FROM (
        SELECT ST_Extent(g) AS e FROM (
          SELECT trajectory(atTime(Trip, {W})) AS g FROM Ships WHERE MMSI = {m}
          UNION ALL SELECT geom FROM ({hermite_sql(m, ta, tb, '10 seconds')}) h ) x ) y""").split("|")
    x0, y0, x1, y1 = map(float, b)
    cx, cy, w, h = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) * 1.12, (y1 - y0) * 1.12
    asp = PX[0] / PX[1]
    if w / h < asp: w = h * asp
    else: h = w / asp
    ext = [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]
    info["extent"] = ext
    summary[name] = info
    lay = lambda l, kind, style: {"type": "vector", "path": f"{name}.gpkg", "layer": l, "kind": kind, "style": style}
    layers = [{"type": "shortbread", "water": "#d6e6f2"},
              lay("track", "line", {"line_color": "#7a7a7a", "line_width": "0.35"}),
              lay("reports", "marker", {"name": "circle", "color": "#4d4d4d", "outline_style": "no", "size": "0.7"})]
    if synthetic:
        layers.append(lay("truth", "line", {"line_color": "#252525", "line_width": "0.5"}))
    layers += [lay("straight", "line", {"line_color": "#1f77b4", "line_width": "0.45", "line_style": "dash"}),
               lay("straight_min", "marker", {"name": "circle", "color": "#ffffff", "outline_color": "#1f77b4", "outline_width": "0.25", "size": "1.3"}),
               lay("curve", "line", {"line_color": "#d62728", "line_width": "0.5"}),
               lay("curve_min", "marker", {"name": "circle", "color": "#d62728", "outline_style": "no", "size": "1.3"})]
    if gap is not None:
        layers.append(lay("model", "marker", {"name": "circle", "color": "#ffffff", "outline_color": "#e8820c", "outline_width": "0.35", "size": "1.5"}))
    layers.append(lay("ends", "marker", {"name": "diamond", "color": "#252525", "outline_style": "no", "size": "2.2"}))
    job = {"output": f"{name}.png", "crs": "EPSG:25832", "extent": ext, "size": list(PX), "dpi": 300,
           "land": "#efeae2", "layers": layers}
    json.dump(job, open(f"{OUT}/job_{name}.json", "w"), indent=1)
json.dump(summary, open(f"{OUT}/summary.json", "w"), indent=1)
print(json.dumps(summary, indent=1))
