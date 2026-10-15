# Writes a map figure as a PDF whose basemap and data layers are vectors except the layers named, which
# are one embedded image (transparent where they draw nothing) between the layers below and above them.
#   <QGIS Python> tracks_image_pdf.py <job.json> <out.pdf> <path substring of the image layers> [native]
# The job is a job of render_map.py, as for hybrid_pdf.py (crs, extent and
# extent_crs, size, dpi, land, layers, optional colorbar, legend and fonts); the image layers must be
# consecutive. The image is lossless (Flate, full colour, its alpha a Flate soft mask), never JPEG.
# With `native`, the image layers are one raster layer in the map's CRS, and the image is that raster's
# own grid over the map, one pixel per cell, placed at the cells' positions: the data cells are written
# as they are rather than resampled to the page's pixels.
import json, sys, os
sys.path.insert(0, os.environ.get('RENDER_MAP_DIR') or os.path.dirname(os.path.abspath(sys.argv[0])))
import render_map as rm
from qgis.core import (QgsApplication, QgsMapSettings, QgsMapRendererCustomPainterJob,
    QgsCoordinateReferenceSystem, QgsRectangle, QgsProject, QgsMapRendererParallelJob,
    QgsCoordinateTransform, QgsVectorTileLayer, QgsRasterLayer)
from qgis.PyQt.QtCore import QSize, QSizeF, QRectF, QMarginsF, QEventLoop
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize, QFontDatabase, QImage

job = json.load(open(sys.argv[1], encoding='utf-8')); out = sys.argv[2]; key = sys.argv[3]
native = len(sys.argv) > 4 and sys.argv[4] == 'native'
app = QgsApplication([], False); app.initQgis()
for path in job.get('fonts', []):
    if QFontDatabase.addApplicationFont(path) < 0:
        raise RuntimeError('invalid font ' + path)
crs = QgsCoordinateReferenceSystem(job['crs'])
extent = QgsRectangle(*job['extent'])
if job.get('extent_crs') and job['extent_crs'] != job['crs']:
    extent = QgsCoordinateTransform(QgsCoordinateReferenceSystem(job['extent_crs']), crs,
                                    QgsProject.instance()).transformBoundingBox(extent)
w, h = job['size']; dpi = job.get('dpi', 300)
layers, isimg = [], []
for spec in job['layers']:
    if spec['type'] == 'shortbread':
        args = (spec.get('water', '#c6dcef'), spec.get('border'), job.get('land', '#f2efe9'),
                spec.get('streets'), spec.get('buildings'))
        layers.append(rm.shortbread_layer(*args[:rm.shortbread_layer.__code__.co_argcount]))
    elif spec['type'] == 'raster':
        layers.append(rm.raster_layer(spec))
    else:
        layers.append(rm.vector_layer(spec))
    isimg.append(key in spec.get('path', ''))
for l in layers:
    QgsProject.instance().addMapLayer(l, False)
# The water outline of hybrid_pdf.py: at least 0.2 mm in the fill colour over the tile edges of the
# basemap when the map is not in Web Mercator
for l in layers:
    if isinstance(l, QgsVectorTileLayer) and crs.authid() != 'EPSG:3857':
        styles = l.renderer().styles()
        for st in styles:
            if st.layerName() in ('ocean', 'water_polygons'):
                sl = st.symbol().symbolLayer(0)
                sl.setStrokeWidth(max(sl.strokeWidth(), 0.2))
        l.renderer().setStyles(styles)
i0 = isimg.index(True); i1 = len(isimg) - isimg[::-1].index(True)
below, image, above = layers[:i0], layers[i0:i1], layers[i1:]


def settings(lyrs, bg, ext=extent, size=(w, h)):
    ms = QgsMapSettings(); ms.setLayers(list(reversed(lyrs))); ms.setDestinationCrs(crs)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(ext); ms.setOutputSize(QSize(*size)); ms.setOutputDpi(dpi)
    ms.setBackgroundColor(bg)
    return ms


# The image and the page rectangle it covers, in page pixels
target = QRectF(0, 0, w, h)
if native:
    r = image[0]
    if len(image) != 1 or not isinstance(r, QgsRasterLayer) or r.crs() != crs:
        raise RuntimeError('native: the image layers must be one raster layer in ' + crs.authid())
    rx, ry = r.rasterUnitsPerPixelX(), r.rasterUnitsPerPixelY(); re_ = r.extent()
    # The cells meeting the map, snapped outwards to the raster's grid
    c0 = max(0, int((extent.xMinimum() - re_.xMinimum()) // rx))
    c1 = min(r.width(), -int(-(extent.xMaximum() - re_.xMinimum()) // rx))
    r0 = max(0, int((re_.yMaximum() - extent.yMaximum()) // ry))
    r1 = min(r.height(), -int(-(re_.yMaximum() - extent.yMinimum()) // ry))
    gext = QgsRectangle(re_.xMinimum() + c0 * rx, re_.yMaximum() - r1 * ry,
                        re_.xMinimum() + c1 * rx, re_.yMaximum() - r0 * ry)
    isize = (c1 - c0, r1 - r0)
    sx, sy = w / extent.width(), h / extent.height()
    target = QRectF((gext.xMinimum() - extent.xMinimum()) * sx, (extent.yMaximum() - gext.yMaximum()) * sy,
                    gext.width() * sx, gext.height() * sy)
    print('native grid', isize, 'cells of', rx, 'x', ry, 'at', target)
    ims = settings(image, QColor(0, 0, 0, 0), gext, isize)
else:
    ims = settings(image, QColor(0, 0, 0, 0))
ijob = QgsMapRendererParallelJob(ims)
loop = QEventLoop(); ijob.finished.connect(loop.quit); ijob.start(); loop.exec_()
img = ijob.renderedImage()
if native:
    # A viewer interpolates an image it enlarges, and the colour of a transparent pixel (black once
    # premultiplied) would then bleed as a dark seam along the edge of the data; each transparent pixel
    # takes the colour of the nearest data pixel, which the mask still hides
    import numpy as np
    img = img.convertToFormat(QImage.Format_ARGB32)
    a = np.frombuffer(img.constBits().asstring(img.sizeInBytes()), np.uint8).reshape(
        img.height(), img.bytesPerLine() // 4, 4)[:, :img.width()].copy()
    known = a[..., 3] > 0
    for _ in range(4):
        if known.all():
            break
        acc = np.zeros(a.shape[:2] + (3,), float); cnt = np.zeros(a.shape[:2], float)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            k = np.roll(known, (dy, dx), (0, 1)); v = np.roll(a[..., :3], (dy, dx), (0, 1))
            acc += v * k[..., None]; cnt += k
        grow = ~known & (cnt > 0)
        a[grow, :3] = (acc[grow] / cnt[grow, None]).round().astype(np.uint8)
        known = known | grow
    img = QImage(a.tobytes(), a.shape[1], a.shape[0], a.shape[1] * 4, QImage.Format_ARGB32).copy()

pdf = QPdfWriter(out); pdf.setResolution(dpi)
pdf.setPageSize(QPageSize(QSizeF(w / dpi * 25.4, h / dpi * 25.4), QPageSize.Millimeter))
pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
p = QPainter(pdf)
for lyrs, bg in ((below, QColor(job.get('land', '#f2efe9'))), (None, None), (above, QColor(0, 0, 0, 0))):
    if lyrs is None:
        # Qt's PDF engine writes an image as JPEG unless the painter asks for lossless images, and the
        # map job drawn before resets the painter's hints; with the hint set here it writes the image
        # Flate-compressed in full colour, its alpha as a Flate soft mask
        p.setRenderHint(QPainter.LosslessImageRendering)
        p.save(); p.setClipRect(QRectF(0, 0, w, h))
        p.drawImage(target, img)
        p.restore()
        continue
    if lyrs or bg.alpha():
        ms = settings(lyrs, bg)
        ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
        QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
p.setRenderHint(QPainter.Antialiasing)
if 'colorbar' in job:
    rm.draw_colorbar(p, job['colorbar'], w, h)
if 'legend' in job:
    rm.draw_legend(p, job['legend'], w, h)
p.end()
print('wrote', out, os.path.getsize(out))
app.exitQgis()
