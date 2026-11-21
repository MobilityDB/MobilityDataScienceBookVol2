# Draws the six panels of the figure of the three cell grids (fig:tess_cellgrids) from
# cellgrids.geojson, whose features carry a "layer" and a "panel", and cellgrids_frames.txt, both
# written by export_cellgrids.sql, over the OpenStreetMap Shortbread vector tiles, each as a PDF
# panel_<panel>.pdf whose basemap, cells, track, protected areas and excerpt frame are all vectors,
# in EPSG:3857. The colours are those of the figure tcell_grids of the MobilityDB manual: the track
# in red, the crossed cells in blue, the protected areas in green. cellgrids_compose.tex sets the
# six panels in the figure.
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
# A panel is 700 x 380 pixels in the manual; 475.4 dpi prints it 37.4 mm wide, a third of the text
# width of the book less the gaps, so that every line width below is its printed width in mm
W, H, DPI = 700, 380, 475.4
app = QgsApplication([], False); app.initQgis()
crs = QgsCoordinateReferenceSystem('EPSG:3857')

LAND, WATER = '#f6f4ee', '#c6deee'
osm = QgsVectorTileLayer(
    'type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/{z}/{x}/{y}.mvt&zmin=0&zmax=14', 'osm')
styles = []
for lname, geom, sym in [
        ('ocean', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.05'})),
        ('water_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.05'})),
        ('buildings', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': '#d6d0c6', 'outline_style': 'no'})),
        ('pier_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': LAND, 'outline_style': 'no'})),
        ('pier_lines', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': LAND, 'line_width': '0.08'})),
        ('streets', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': '#d6cdbf', 'line_width': '0.04'}))]:
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
            {'style': 'no', 'outline_color': '#282828', 'outline_width': '0.16'})),
        layer('track', panel, QgsLineSymbol.createSimple({'line_color': '#c82d2d', 'line_width': '0.16'})),
        layer('crossed', panel, QgsFillSymbol.createSimple(
            {'color': '66,146,198,96', 'outline_color': '#2e6096', 'outline_width': '0.08'})),
        layer('grid', panel, QgsFillSymbol.createSimple(
            {'style': 'no', 'outline_color': '#78808c', 'outline_width': '0.05'})),
        layer('mpa', panel, QgsFillSymbol.createSimple(
            {'color': '86,138,86,89', 'outline_color': '#568a56', 'outline_width': '0.06'}))]
    if panel not in ('h3_8', 'quadbin_15', 's2_14'):
        data = data[1:]          # the excerpt frame is drawn on the upper row only
    ms = QgsMapSettings(); ms.setLayers(data + [osm]); ms.setDestinationCrs(crs)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(extent); ms.setOutputSize(QSize(W, H)); ms.setOutputDpi(DPI)
    ms.setBackgroundColor(QColor(LAND))
    # Markers and vector tiles are otherwise cached as images; this keeps every symbol a vector
    ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
    pdfpath = os.path.join(d, f'panel_{panel}.pdf')
    pdf = QPdfWriter(pdfpath); pdf.setResolution(int(DPI))
    pdf.setPageSize(QPageSize(QSizeF(W / DPI * 25.4, H / DPI * 25.4), QPageSize.Millimeter))
    pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
    p = QPainter(pdf)
    QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
    p.end()
    print('wrote', pdfpath, os.path.getsize(pdfpath))
app.exitQgis()
