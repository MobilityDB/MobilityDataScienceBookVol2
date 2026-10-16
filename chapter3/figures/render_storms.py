# Draws a map of Fig. storms of chapter 3 as a vector PDF: the basemap (the OSM Shortbread vector
# tiles: ocean, lakes and country boundaries) and the data layers in ONE
# QgsMapRendererCustomPainterJob with ForceVectorOutput, so that the PDF holds no image. The
# destination CRS comes from the spec (EPSG:4326 by default), and each data layer is drawn in the
# order of its "ord" property.
# With "image_layers" (data layer names, consecutive in the spec), those layers are ONE embedded
# image at the page's 300 dpi between the vector layers below and above them, lossless (Flate, full
# colour, its alpha a Flate soft mask).
# <python of QGIS> render_storms.py <spec.json> [info]
# The spec names the GeoJSON written by storms_export.sql, the output PDF, both relative to the
# directory of the spec, the CRS of the map, the extent (bbox [x1, y1, x2, y2] in the units of that
# CRS, widened to the aspect of the page), the page size in pixels at 300 dpi, the data layers from top to bottom with their colours,
# and the tile zoom of each basemap layer. With "info", it prints the extent, scale and zooms only.
import sys, os, json, time
from qgis.core import (QgsApplication, QgsVectorLayer, QgsMapSettings, QgsCoordinateReferenceSystem,
    QgsRectangle, QgsSingleSymbolRenderer, QgsWkbTypes,
    QgsMarkerSymbol, QgsLineSymbol, QgsFillSymbol, QgsVectorTileLayer, QgsVectorTileBasicRenderer,
    QgsVectorTileBasicRendererStyle, QgsMapRendererCustomPainterJob, QgsFeatureRequest,
    QgsMapRendererParallelJob)
from qgis.PyQt.QtCore import QSize, QSizeF, QMarginsF, QRectF, QEventLoop
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize

spec = json.load(open(sys.argv[1])); mode = sys.argv[2] if len(sys.argv) > 2 else 'vt'
base = os.path.dirname(os.path.abspath(sys.argv[1]))
src = os.path.join(base, spec['geojson'])
app = QgsApplication([], False); app.initQgis()
# The CRS is an authority code, such as EPSG:4326, or a PROJ string, such as the Lambert azimuthal
# equal-area projection centred on the basin that the maps use
crs_def = spec.get('crs', 'EPSG:4326')
crs = (QgsCoordinateReferenceSystem.fromProj(crs_def) if crs_def.startswith('+proj')
       else QgsCoordinateReferenceSystem(crs_def))
if not crs.isValid():
    raise RuntimeError('invalid CRS ' + crs_def)

LAND, WATER, BORDER = '#f2efe9', '#aad3df', '#a29cb4'
# The water outline (0.3 mm in the water colour) hides the tile edges; a "base_gpkg" whose water is
# already buffered by half that outline is drawn with "water_outline": 0, the water filled only
WOUT = spec.get('water_outline', 0.3)
WSYM = {'color': WATER, 'outline_color': WATER, 'outline_width': str(WOUT)}
if WOUT == 0:
    WSYM = {'color': WATER, 'outline_style': 'no'}
BASE = [
    ('ocean', QgsWkbTypes.PolygonGeometry, None,
     lambda: QgsFillSymbol.createSimple(WSYM)),
    ('water_polygons', QgsWkbTypes.PolygonGeometry, '"way_area" > ' + str(spec.get('min_lake_m2', 0)),
     lambda: QgsFillSymbol.createSimple(WSYM)),
    ('boundaries', QgsWkbTypes.LineGeometry,
     '"admin_level" = 2 AND coalesce("maritime", false) = false',
     lambda: QgsLineSymbol.createSimple({'line_color': BORDER, 'line_width': str(spec.get('border_width', 0.15)),
                                         'capstyle': 'round', 'joinstyle': 'round'}))]
# One vector tile layer per Shortbread layer, read at the tile zoom of the spec ("zoom": {layer: z}):
# the lakes exist only from z5, while the ocean and the boundaries of z4 suffice at this scale
def tile_layer(lname, geom, flt, sym):
    z = spec.get('zoom', {}).get(lname, spec.get('zmin', 0))
    lyr = QgsVectorTileLayer(
        f'type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/{{z}}/{{x}}/{{y}}.mvt&zmin={z}&zmax={z}',
        lname)
    st = QgsVectorTileBasicRendererStyle(lname, lname, geom)
    st.setSymbol(sym())
    if flt:
        st.setFilterExpression(flt)
    vtr = QgsVectorTileBasicRenderer(); vtr.setStyles([st]); lyr.setRenderer(vtr)
    return lyr
tiles = [tile_layer(*b) for b in reversed(BASE)]  # top first
# With "base_gpkg", the basemap is read from a GeoPackage holding the same Shortbread layers at the
# same zooms and filters, merged across tiles, so that the PDF holds no tile edge and no clip path
# per tile
if spec.get('base_gpkg'):
    tiles = []
    for lname, geom, flt, sym in reversed(BASE):
        lyr = QgsVectorLayer(os.path.join(base, spec['base_gpkg']) + '|layername=' + lname, lname, 'ogr')
        if not lyr.isValid():
            raise RuntimeError('no layer ' + lname + ' in ' + spec['base_gpkg'])
        lyr.setRenderer(QgsSingleSymbolRenderer(sym()))
        tiles.append(lyr)

def symbol(l):
    t = l['type']
    if t == 'point':
        return QgsMarkerSymbol.createSimple({'name': 'circle', 'color': l['color'],
            'outline_color': l.get('outline', '#000000'), 'outline_width': str(l.get('outline_width', 0.1)),
            'size': str(l.get('size', 1.2))})
    if t == 'line':
        return QgsLineSymbol.createSimple({'line_color': l['color'], 'line_width': str(l.get('width', 0.4)),
            'capstyle': 'round', 'joinstyle': 'round'})
    return QgsFillSymbol.createSimple({'color': l['color'], 'outline_color': l.get('outline', '#000000'),
        'outline_width': str(l.get('outline_width', 0.1)), 'joinstyle': 'round'})

# Spec layers are listed top first, as QgsMapSettings lists them
data = []
for l in spec['layers']:
    lyr = QgsVectorLayer(src, l['name'], 'ogr')
    lyr.setSubsetString(f"\"layer\" = '{l['name']}'")
    if lyr.featureCount() == 0:
        continue
    r = QgsSingleSymbolRenderer(symbol(l))
    r.setOrderBy(QgsFeatureRequest.OrderBy([QgsFeatureRequest.OrderByClause('ord', True)]))
    r.setOrderByEnabled(True)
    lyr.setRenderer(r)
    data.append(lyr)

w, h = spec['width'], spec['height']
x1, y1, x2, y2 = spec['bbox']
rect = QgsRectangle(x1, y1, x2, y2)
# Widen the shorter side so that the extent has the aspect of the page
cx, cy = rect.center().x(), rect.center().y()
hw, hh = rect.width() / 2, rect.height() / 2
if hw / hh < w / h: hw = hh * w / h
else: hh = hw * h / w
rect = QgsRectangle(cx - hw, cy - hh, cx + hw, cy + hh)

ms = QgsMapSettings()
ms.setLayers(data + tiles); ms.setDestinationCrs(crs); ms.setExtent(rect)
ms.setOutputSize(QSize(w, h)); ms.setOutputDpi(300)
ms.setBackgroundColor(QColor(LAND))
ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
z = [(t.name(), t.sourceMinZoom()) for t in tiles if isinstance(t, QgsVectorTileLayer)]
print('extent', rect.xMinimum(), rect.yMinimum(), rect.xMaximum(), rect.yMaximum())
print('scale', ms.scale(), 'zoom', z, 'size', w, h)
if mode == 'info':
    app.exitQgis(); sys.exit(0)

pdfpath = os.path.join(base, spec['out'])
t0 = time.time()
pdf = QPdfWriter(pdfpath); pdf.setResolution(300)
pdf.setPageSize(QPageSize(QSizeF(w / 300 * 25.4, h / 300 * 25.4), QPageSize.Millimeter))
pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
p = QPainter(pdf)
img_names = set(spec.get('image_layers', []))
if not img_names:
    QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
else:
    # The layers of `ms` (top first) split into those above, those drawn as the image, and those below
    lyrs = data + tiles
    isimg = [l.name() in img_names for l in lyrs]
    i0 = isimg.index(True); i1 = len(isimg) - isimg[::-1].index(True)
    if not all(isimg[i0:i1]):
        raise RuntimeError('image_layers must be consecutive')
    above, image, below = lyrs[:i0], lyrs[i0:i1], lyrs[i1:]

    # A copy of `ms` with the given layers and background
    def settings(ls, bg):
        m = QgsMapSettings(ms); m.setLayers(ls); m.setBackgroundColor(bg)
        return m
    im = settings(image, QColor(0, 0, 0, 0)); im.setFlag(QgsMapSettings.ForceVectorOutput, False)
    ijob = QgsMapRendererParallelJob(im)
    loop = QEventLoop(); ijob.finished.connect(loop.quit); ijob.start(); loop.exec_()
    img = ijob.renderedImage()
    QgsMapRendererCustomPainterJob(settings(below, QColor(LAND)), p).renderSynchronously()
    # Qt's PDF engine writes an image as JPEG unless the painter asks for lossless images, and the map
    # job drawn before resets the painter's hints
    p.setRenderHint(QPainter.LosslessImageRendering)
    p.save(); p.setClipRect(QRectF(0, 0, w, h)); p.drawImage(QRectF(0, 0, w, h), img); p.restore()
    if above:
        QgsMapRendererCustomPainterJob(settings(above, QColor(0, 0, 0, 0)), p).renderSynchronously()
p.end()
print('wrote', pdfpath, os.path.getsize(pdfpath), 'seconds', round(time.time() - t0, 1))
app.exitQgis()
