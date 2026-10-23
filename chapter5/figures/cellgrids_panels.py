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

# Draws the six panels of the figure of the three cell grids (cellgrids.geojson, whose features
# carry a "layer" and a "panel", and cellgrids_frames.txt, both written by export_cellgrids.sql)
# over the OpenStreetMap Shortbread vector tiles, each as a PDF panel_<panel>.pdf whose basemap,
# cells, track, protected area and excerpt frame are all vectors. The colours are those of the
# ship figures of the book: the track of the vessel in blue, the protected area in green.
# cellgrids_compose.tex sets the six panels in the figure.
#   <python of QGIS> cellgrids_panels.py <directory holding cellgrids.geojson>
import sys, os
from qgis.core import (QgsApplication, QgsVectorLayer, QgsMapSettings,
    QgsMapRendererCustomPainterJob, QgsCoordinateReferenceSystem, QgsRectangle, QgsProject,
    QgsSingleSymbolRenderer, QgsWkbTypes, QgsLineSymbol, QgsFillSymbol, QgsVectorTileLayer,
    QgsVectorTileBasicRenderer, QgsVectorTileBasicRendererStyle)
from qgis.PyQt.QtCore import QSize, QSizeF, QMarginsF
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize

d = sys.argv[1]
src = os.path.join(d, 'cellgrids.geojson')
W, H, DPI = 700, 380, 300
app = QgsApplication([], False); app.initQgis()
crs = QgsCoordinateReferenceSystem('EPSG:25832')

LAND, WATER = '#f2efe9', '#c6dcef'
osm = QgsVectorTileLayer(
    'type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/{z}/{x}/{y}.mvt&zmin=0&zmax=14', 'osm')
styles = []
for lname, geom, sym in [
        ('ocean', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.3'})),
        ('water_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.3'})),
        ('buildings', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': '#e3dbd0', 'outline_style': 'no'})),
        ('pier_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': LAND, 'outline_style': 'no'})),
        ('pier_lines', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': LAND, 'line_width': '0.4'})),
        ('streets', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': '#d6cdbf', 'line_width': '0.15'}))]:
    st = QgsVectorTileBasicRendererStyle(lname, lname, geom)
    st.setSymbol(sym); styles.append(st)
vtr = QgsVectorTileBasicRenderer(); vtr.setStyles(styles); osm.setRenderer(vtr)
QgsProject.instance().addMapLayer(osm, False)

def layer(name, panel, symbol):
    l = QgsVectorLayer(src, name, 'ogr')
    l.setSubsetString(f"\"layer\" = '{name}' AND (\"panel\" = '{panel}' OR \"panel\" = 'all')")
    l.setRenderer(QgsSingleSymbolRenderer(symbol))
    QgsProject.instance().addMapLayer(l, False)
    return l

frames = {}
for line in open(os.path.join(d, 'cellgrids_frames.txt')):
    p, *v = line.strip().split('|')
    if p:
        frames[p] = QgsRectangle(*map(float, v))

for panel, extent in frames.items():
    data = [
        layer('excerpt', panel, QgsFillSymbol.createSimple(
            {'style': 'no', 'outline_color': '#000000', 'outline_width': '0.45'})),
        layer('track', panel, QgsLineSymbol.createSimple({'line_color': '#0000ff', 'line_width': '0.45'})),
        layer('crossed', panel, QgsFillSymbol.createSimple(
            {'color': '66,146,198,120', 'outline_color': '#08519c', 'outline_width': '0.25'})),
        layer('grid', panel, QgsFillSymbol.createSimple(
            {'style': 'no', 'outline_color': '#5a6b7d', 'outline_width': '0.12'})),
        layer('mpa', panel, QgsFillSymbol.createSimple(
            {'color': '40,170,80,120', 'outline_color': '0,110,40', 'outline_width': '0.25'}))]
    if panel not in ('h3_8', 'quadbin_15', 's2_14'):
        data = data[1:]          # the excerpt frame is drawn on the left panels only
    ms = QgsMapSettings(); ms.setLayers(data + [osm]); ms.setDestinationCrs(crs)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(extent); ms.setOutputSize(QSize(W, H)); ms.setOutputDpi(DPI)
    ms.setBackgroundColor(QColor(LAND))
    # Markers and vector tiles are otherwise cached as images; this keeps every symbol a vector
    ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
    pdfpath = os.path.join(d, f'panel_{panel}.pdf')
    pdf = QPdfWriter(pdfpath); pdf.setResolution(DPI)
    pdf.setPageSize(QPageSize(QSizeF(W / DPI * 25.4, H / DPI * 25.4), QPageSize.Millimeter))
    pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
    p = QPainter(pdf)
    QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
    p.end()
    print('wrote', pdfpath, os.path.getsize(pdfpath))
app.exitQgis()
