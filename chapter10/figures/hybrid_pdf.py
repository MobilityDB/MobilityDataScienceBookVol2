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

# Writes a map figure as a vector PDF: the OSM Shortbread vector-tile basemap, the data layers, their
# labels, the colorbar and the legend are all vectors, so that the basemap, cells, tracks and outlines
# stay sharp at any zoom; only a raster data layer (a bathymetry, a slope) is an embedded image.
#   <QGIS Python> hybrid_pdf.py <job.json> <out.pdf>
# The job is a job of render_map.py (crs, extent, size, dpi, land, layers, optional colorbar, legend
# and fonts), its layers bottom to top. render_map.py is imported from the directory RENDER_MAP_DIR
# names, else from the directory of this script.
import json, sys, os
sys.path.insert(0, os.environ.get('RENDER_MAP_DIR') or os.path.dirname(os.path.abspath(sys.argv[0])))
import render_map as rm
from qgis.core import (QgsApplication, QgsMapSettings, QgsMapRendererCustomPainterJob,
    QgsCoordinateReferenceSystem, QgsRectangle, QgsProject, QgsCoordinateTransform, QgsVectorTileLayer)
from qgis.PyQt.QtCore import QSize, QSizeF, QMarginsF
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize, QFontDatabase

job = json.load(open(sys.argv[1], encoding='utf-8')); out = sys.argv[2]
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
# The layers bottom to top, built as render_map.main builds them
layers = []
for spec in job['layers']:
    if spec['type'] == 'shortbread':
        # The renderers of the book take two (water, border) or five arguments
        args = (spec.get('water', '#c6dcef'), spec.get('border'), job.get('land', '#f2efe9'),
                spec.get('streets'), spec.get('buildings'))
        n = rm.shortbread_layer.__code__.co_argcount
        layers.append(rm.shortbread_layer(*args[:n]))
    elif spec['type'] == 'raster':
        layers.append(rm.raster_layer(spec))
    else:
        layers.append(rm.vector_layer(spec))
        # "color_field": the fill colour of each feature is read from that attribute ("r,g,b,a"), as
        # for the cells of a raster drawn as polygons in the colours its ramp gives their values
        if 'color_field' in spec:
            from qgis.core import QgsProperty, QgsSymbolLayer
            sl = layers[-1].renderer().symbol().symbolLayer(0)
            sl.setDataDefinedProperty(QgsSymbolLayer.PropertyFillColor,
                                      QgsProperty.fromField(spec['color_field']))
for l in layers:
    QgsProject.instance().addMapLayer(l, False)
# Each tile of the basemap is clipped on its own, and a reprojected tile edge leaves a hairline of land
# between two water polygons that a vector page shows at any zoom; a water outline of at least 0.2 mm
# in the fill colour covers it. In Web Mercator, the tiles' own CRS, the edges meet exactly and the
# outline is left as the job draws it, which keeps small lakes their size
for l in layers:
    if isinstance(l, QgsVectorTileLayer) and crs.authid() != 'EPSG:3857':
        styles = l.renderer().styles()
        for st in styles:
            if st.layerName() in ('ocean', 'water_polygons'):
                sl = st.symbol().symbolLayer(0)
                sl.setStrokeWidth(max(sl.strokeWidth(), 0.2))
        l.renderer().setStyles(styles)

# The map: every layer in one job, the land as its background, at the figure's nominal dpi
ms = QgsMapSettings(); ms.setLayers(list(reversed(layers))); ms.setDestinationCrs(crs)
ms.setTransformContext(QgsProject.instance().transformContext())
ms.setExtent(extent); ms.setOutputSize(QSize(w, h)); ms.setOutputDpi(dpi)
ms.setBackgroundColor(QColor(job.get('land', '#f2efe9')))
# Markers and vector tiles are otherwise cached as images; this keeps every symbol a vector
ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
# Qt's PDF engine writes a raster layer as JPEG unless the painter asks for lossless images; this flag
# has the map job ask for it, so the raster data are written Flate-compressed in full colour
ms.setFlag(QgsMapSettings.LosslessImageRendering, True)
# The frame of the page, from which the tile edges of the basemap are found
tiles = [l for l in layers if isinstance(l, QgsVectorTileLayer)]
print('frame', crs.authid(), ms.extent().xMinimum(), ms.extent().yMinimum(), ms.extent().xMaximum(),
      ms.extent().yMaximum(), w, h, 'scale', ms.scale(),
      'zoom', tiles[0].tileMatrixSet().scaleToZoomLevel(ms.scale()) if tiles else None)

# The page: the figure's physical size at its nominal dpi
pdf = QPdfWriter(out); pdf.setResolution(dpi)
pdf.setPageSize(QPageSize(QSizeF(w / dpi * 25.4, h / dpi * 25.4), QPageSize.Millimeter))
pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
p = QPainter(pdf)
QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
p.setRenderHint(QPainter.Antialiasing)
if 'colorbar' in job:
    rm.draw_colorbar(p, job['colorbar'], w, h)
if 'legend' in job:
    rm.draw_legend(p, job['legend'], w, h)
p.end()
print('wrote', out, os.path.getsize(out))
app.exitQgis()
