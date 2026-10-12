"""Render the map figures of chapter 4 with PyQGIS.

Usage: <the Python of QGIS> render_figures.py spec.json, as render.sh runs it
The spec, written by an export script, is a list of figures; each one has an
output path, an extent in EPSG:4326, a width in pixels, and a list of GeoJSON
layers drawn over an OpenStreetMap basemap (first layer drawn on top). The
paths are relative to the working directory.
"""
import sys
import json
from qgis.core import (QgsApplication, QgsProject, QgsVectorLayer,
    QgsRasterLayer, QgsMapSettings, QgsMapRendererParallelJob,
    QgsCoordinateReferenceSystem, QgsCoordinateTransform, QgsRectangle,
    QgsFillSymbol, QgsLineSymbol, QgsMarkerSymbol, QgsSingleSymbolRenderer)
from qgis.PyQt.QtCore import QSize
from qgis.PyQt.QtGui import QColor

app = QgsApplication([], False)
app.initQgis()
crs3857 = QgsCoordinateReferenceSystem('EPSG:3857')
crs4326 = QgsCoordinateReferenceSystem('EPSG:4326')
tr = QgsCoordinateTransform(crs4326, crs3857, QgsProject.instance())

def symbol(spec):
    kind = spec['type']
    if kind == 'polygon':
        return QgsFillSymbol.createSimple({
            'color': spec.get('fill', '0,0,255,80'),
            'outline_color': spec.get('stroke', '0,0,0,255'),
            'outline_width': str(spec.get('width', 0.3)),
            'outline_width_unit': 'MM',
            'outline_style': spec.get('style', 'solid')})
    if kind == 'line':
        return QgsLineSymbol.createSimple({
            'color': spec.get('stroke', '0,0,255,255'),
            'width': str(spec.get('width', 0.6)), 'width_unit': 'MM',
            'line_style': spec.get('style', 'solid'), 'capstyle': 'round'})
    return QgsMarkerSymbol.createSimple({
        'name': spec.get('shape', 'circle'),
        'color': spec.get('fill', '255,0,0,255'),
        'outline_color': spec.get('stroke', '0,0,0,255'),
        'size': str(spec.get('size', 1.5))})

for fig in json.load(open(sys.argv[1])):
    e = fig['extent']
    rect = tr.transformBoundingBox(QgsRectangle(e[0], e[1], e[2], e[3]))
    width = fig.get('width', 1600)
    height = int(round(width * rect.height() / rect.width()))
    layers = []
    for spec in fig['layers']:
        vl = QgsVectorLayer(spec['file'], spec.get('name', 'layer'), 'ogr')
        if not vl.isValid() or vl.featureCount() == 0:
            print('skipped empty layer', spec['file'])
            continue
        vl.setRenderer(QgsSingleSymbolRenderer(symbol(spec)))
        layers.append(vl)
    if fig.get('basemap', True):
        url = ('type=xyz&url=https://tile.openstreetmap.org/{z}/{x}/{y}.png'
               '&zmax=19&zmin=0')
        base = QgsRasterLayer(url, 'OpenStreetMap', 'wms')
        if base.isValid():
            layers.append(base)
        else:
            print('basemap not available')
    ms = QgsMapSettings()
    ms.setLayers(layers)
    ms.setDestinationCrs(crs3857)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(rect)
    ms.setOutputSize(QSize(width, height))
    ms.setOutputDpi(fig.get('dpi', 200))
    ms.setBackgroundColor(QColor(255, 255, 255))
    job = QgsMapRendererParallelJob(ms)
    job.start()
    job.waitForFinished()
    job.renderedImage().save(fig['out'], 'png')
    print('wrote', fig['out'], width, height)

app.exitQgis()
