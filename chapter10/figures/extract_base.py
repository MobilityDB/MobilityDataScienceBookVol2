# Writes the Shortbread features of a map extent as a GeoPackage in EPSG:3857, one layer per Shortbread
# layer the maps of the book draw (ocean, water polygons, buildings, piers, streets), with the tiles
# merged: polygons dissolved per layer, lines merged, everything clipped to the extent plus a margin,
# so that the PDF has no tile edge and no clip path.
#   extract_base.py <zoom> <xmin> <ymin> <xmax> <ymax> <out.gpkg>
# The extent is in EPSG:3857. The tiles are those QGIS draws at that zoom, fetched from the OSM
# Shortbread tile server into tiles/<z>/<x>/<y>.mvt beside <out.gpkg>; GDAL's MVT driver reads each
# tile georeferenced from its z/x/y path.
import sys, os, subprocess
from osgeo import ogr, osr, gdal
from shapely import wkb, union_all, line_merge, box, make_valid
gdal.UseExceptions()
z = int(sys.argv[1]); x0, y0, x1, y1 = map(float, sys.argv[2:6]); out = sys.argv[6]
LAYERS = {'ocean': 'poly', 'water_polygons': 'poly', 'buildings': 'poly', 'pier_polygons': 'poly',
          'pier_lines': 'line', 'streets': 'line'}
O = 20037508.342789244; t = 2 * O / 2 ** z
m = 0.02 * max(x1 - x0, y1 - y0)
ext = box(x0 - m, y0 - m, x1 + m, y1 + m)
cache = os.path.join(os.path.dirname(os.path.abspath(out)), 'tiles')
geoms = {k: [] for k in LAYERS}
for tx in range(int((x0 - m + O) // t), int((x1 + m + O) // t) + 1):
    for ty in range(int((O - y1 - m) // t), int((O - y0 + m) // t) + 1):
        p = os.path.join(cache, str(z), str(tx), f'{ty}.mvt')
        if not os.path.exists(p):
            os.makedirs(os.path.dirname(p), exist_ok=True)
            subprocess.run(['curl', '-sfL', '-A', 'MobilityBook-figures', '-o', p,
                f'https://vector.openstreetmap.org/shortbread_v1/{z}/{tx}/{ty}.mvt'], check=True)
        ds = ogr.Open(p)
        if ds is None:
            continue
        for k in LAYERS:
            lyr = ds.GetLayerByName(k)
            if lyr is None:
                continue
            for f in lyr:
                g = f.GetGeometryRef()
                if g is not None:
                    geoms[k].append(make_valid(wkb.loads(bytes(g.ExportToWkb()))))
srs = osr.SpatialReference(); srs.ImportFromEPSG(3857)
if os.path.exists(out):
    os.remove(out)
dst = ogr.GetDriverByName('GPKG').CreateDataSource(out)
for k, kind in LAYERS.items():
    if not geoms[k]:
        continue
    if kind == 'poly':
        parts = [g for g in geoms[k] if g.geom_type in ('Polygon', 'MultiPolygon', 'GeometryCollection')]
        g = union_all(parts).intersection(ext)
        g = union_all([p for p in getattr(g, 'geoms', [g]) if p.geom_type in ('Polygon', 'MultiPolygon')])
        ot = ogr.wkbMultiPolygon
    else:
        parts = [g for g in geoms[k] if 'LineString' in g.geom_type]
        g = line_merge(union_all(parts)).intersection(ext)
        ot = ogr.wkbMultiLineString
    if g.is_empty:
        continue
    lyr = dst.CreateLayer(k, srs, ot)
    f = ogr.Feature(lyr.GetLayerDefn())
    f.SetGeometry(ogr.ForceTo(ogr.CreateGeometryFromWkb(g.wkb), ot))
    lyr.CreateFeature(f)
    print(k, len(geoms[k]), 'tile features ->', g.geom_type, len(getattr(g, 'geoms', [g])), 'parts')
dst = None
