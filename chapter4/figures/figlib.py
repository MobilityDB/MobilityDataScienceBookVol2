"""The helpers shared by the export scripts of the chapter 4 figures.

Every geometry of a map figure is the result of a MobilityDB query, written as
GeoJSON in EPSG:4326 into the directory $OUT (default: out/ below the working
directory), together with a spec that render.sh draws with QGIS as vector PDFs over the
OpenStreetMap Shortbread vector tiles. The files of a spec are named relative to $OUT, where
render.sh runs the renderer.

As the export scripts of chapter 5 do (chapter5/figures/export_traffic_h3.sh),
the database comes from the PostgreSQL environment variables (PGHOST, PGPORT,
PGUSER); the names of the AIS and nuScenes databases are AIS_DB and NUSCENES_DB
(default: ais and nuscenes). The session runs in UTC, the time of the AIS data,
in which the timestamps of the queries are written.

Chapter 5 exports its layers with ogr2ogr from one query each, and has no
Python helpers to share (rule 4 of the sibling search): these are built beside
#vector_layer of chapter5/figures/render_map.py, which draws such layers.
"""
import json
import math
import os
import psycopg2

OUT = os.environ.get('OUT', os.path.join(os.getcwd(), 'out'))
os.makedirs(OUT, exist_ok=True)
SPECS = []

def connect(db):
    """Connect to the AIS ('ais') or the nuScenes ('nuscenes') database"""
    name = os.environ.get(db.upper() + '_DB', db)
    return psycopg2.connect(dbname=name, options='-c TimeZone=UTC')

def geo(expr):
    """The SQL expression of the GeoJSON in EPSG:4326 of a geometry"""
    return f"ST_AsGeoJSON(ST_Transform(ST_Force2D({expr}), 4326), 8)"

def collection(cur, sql, args=(), xform=None):
    """A GeoJSON feature collection from a query whose first column is GeoJSON
    and whose other columns become the properties of the features; xform maps
    the geometry of each feature, for instance from a local frame to EPSG:4326"""
    cur.execute(sql, args)
    cols = [d[0] for d in cur.description]
    feats = []
    for row in cur.fetchall():
        if row[0] is None:
            continue
        g = json.loads(row[0])
        if xform:
            g = xform(g)
        props = {c: (v if isinstance(v, (int, float, str)) or v is None
                     else str(v)) for c, v in zip(cols[1:], row[1:])}
        feats.append({'type': 'Feature', 'geometry': g, 'properties': props})
    return {'type': 'FeatureCollection', 'features': feats}

def save(name, fc):
    """Write a feature collection into $OUT and return its name relative to $OUT"""
    with open(os.path.join(OUT, f'{name}.geojson'), 'w') as f:
        json.dump(fc, f)
    print(f'  {name}: {len(fc["features"])} features')
    return f'{name}.geojson'

def bbox(*fcs, pad=0.15, aspect=None):
    """The extent [x0, y0, x1, y1] in EPSG:4326 of feature collections, padded
    by a fraction of its size and widened to the ratio aspect = width / height
    in metres"""
    xs, ys = [], []
    def walk(c):
        if isinstance(c[0], (int, float)):
            xs.append(c[0]); ys.append(c[1])
        else:
            for x in c:
                walk(x)
    for fc in fcs:
        for f in fc['features']:
            walk(f['geometry']['coordinates'])
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    dx, dy = (x1 - x0) or 1e-4, (y1 - y0) or 1e-4
    x0, x1, y0, y1 = x0 - pad * dx, x1 + pad * dx, y0 - pad * dy, y1 + pad * dy
    if aspect:
        k = math.cos(math.radians((y0 + y1) / 2))
        w, h = (x1 - x0) * k, y1 - y0
        if w / h < aspect:
            extra = (aspect * h - w) / k / 2
            x0, x1 = x0 - extra, x1 + extra
        else:
            extra = (w / aspect - h) / 2
            y0, y1 = y0 - extra, y1 + extra
    return [x0, y0, x1, y1]

def figure(out, extent, layers, width=1800):
    """Add a map figure to the spec; the first layer is drawn on top"""
    SPECS.append({'out': out, 'extent': extent, 'width': width, 'layers': layers})

def write_spec(name):
    """Write the spec of the map figures into $OUT, for render.sh"""
    with open(os.path.join(OUT, name), 'w') as f:
        json.dump(SPECS, f, indent=1)
    print(f'{name}: {len(SPECS)} map figures')

# The styles of the layers
HULL = {'type': 'polygon', 'fill': '255,140,0,150', 'stroke': '120,60,0,255',
        'width': 0.25}
SWEPT = {'type': 'polygon', 'fill': '30,90,220,70', 'stroke': '30,90,220,255',
         'width': 0.3}
TRACK = {'type': 'line', 'stroke': '0,0,255,255', 'width': 0.6}
RED_HULL = {'type': 'polygon', 'fill': '220,0,0,200', 'stroke': '120,0,0,255',
            'width': 0.25}
