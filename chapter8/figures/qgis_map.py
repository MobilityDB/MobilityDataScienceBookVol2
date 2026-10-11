"""Render a map figure of chapter 8 with QGIS as a PDF: basemap image, data layers as vectors.

Usage (from WSL, through render.sh):
  cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" qgis_map.py job.json out.pdf

The job states the size of the figure in pixels of 300 dpi of its printed size, its extent in
EPSG:3857, the land color and its layers from bottom to top, as the jobs of
chapter5/figures/render_map.py. The first layer is the basemap, the OSM Shortbread vector tiles
styled as the maps of the book (land, water, light buildings and streets, no label), drawn as
one image of 300 dpi. The other layers are GeoJSON files drawn as vectors on top, except those
marked "image", a dense layer (more than some 30,000 marks) or a density surface, which are
drawn together as one transparent image of 300 dpi at their place in the order of the layers.
A vector layer takes the color of each feature from its field "color" when the layer names it.
"""
import json
import sys

from qgis.core import (
    QgsApplication, QgsCoordinateReferenceSystem, QgsRectangle, QgsMapSettings,
    QgsMapRendererParallelJob, QgsMapRendererCustomPainterJob, QgsVectorLayer, QgsRasterLayer,
    QgsVectorTileLayer, QgsVectorTileBasicRenderer, QgsVectorTileBasicRendererStyle,
    QgsFillSymbol, QgsLineSymbol, QgsMarkerSymbol, QgsWkbTypes, QgsProject, QgsProperty,
    QgsSymbolLayer)
from qgis.PyQt.QtCore import QSize, QSizeF, QRectF, QMarginsF, QEventLoop
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize

SHORTBREAD = ("type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/"
              "{z}/{x}/{y}.mvt&zmin=0&zmax=14")


def shortbread_layer(water, land, streets=None, buildings=None, border=None):
    """The Shortbread basemap of the book, as #shortbread_layer of the render_map.py of the
    figures of the book draws it: water over the land color, piers in the land color, and
    optional buildings, streets and borders."""
    layer = QgsVectorTileLayer(SHORTBREAD, "shortbread")
    styles = []
    for name in ("ocean", "water_polygons"):
        st = QgsVectorTileBasicRendererStyle(name, name, QgsWkbTypes.PolygonGeometry)
        # An outline in the fill color closes the hairline seam between tiles
        st.setSymbol(QgsFillSymbol.createSimple(
            {"color": water, "outline_color": water, "outline_width": "0.1"}))
        styles.append(st)
    st = QgsVectorTileBasicRendererStyle("water_lines", "water_lines", QgsWkbTypes.LineGeometry)
    st.setSymbol(QgsLineSymbol.createSimple({"color": water, "width": "0.2"}))
    styles.append(st)
    for name in ("pier_polygons", "dam_polygons"):
        st = QgsVectorTileBasicRendererStyle(name, name, QgsWkbTypes.PolygonGeometry)
        st.setSymbol(QgsFillSymbol.createSimple({"color": land, "outline_style": "no"}))
        styles.append(st)
    if buildings:
        st = QgsVectorTileBasicRendererStyle("buildings", "buildings", QgsWkbTypes.PolygonGeometry)
        st.setSymbol(QgsFillSymbol.createSimple({"color": buildings, "outline_style": "no"}))
        styles.append(st)
    if streets:
        st = QgsVectorTileBasicRendererStyle("streets", "streets", QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple({"color": streets, "width": str(streets_width)}))
        styles.append(st)
    if border:
        st = QgsVectorTileBasicRendererStyle("boundaries", "boundaries", QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple(
            {"color": border, "width": "0.15", "line_style": "dash"}))
        styles.append(st)
    renderer = QgsVectorTileBasicRenderer()
    renderer.setStyles(styles)
    layer.setRenderer(renderer)
    return layer


def vector_layer(spec):
    layer = QgsVectorLayer(spec["path"], spec.get("name", "vector"), "ogr")
    if not layer.isValid():
        raise RuntimeError("invalid vector " + spec["path"])
    kind = spec.get("kind", "fill")
    make = {"fill": QgsFillSymbol, "line": QgsLineSymbol, "marker": QgsMarkerSymbol}[kind]
    sym = make.createSimple(spec["style"])
    if spec.get("color_field"):
        prop = QgsProperty.fromField(spec["color_field"])
        sl = sym.symbolLayer(0)
        key = QgsSymbolLayer.PropertyStrokeColor if kind == "line" else QgsSymbolLayer.PropertyFillColor
        sl.setDataDefinedProperty(key, prop)
    layer.renderer().setSymbol(sym)
    return layer


def image_layer(spec):
    """A georeferenced RGBA image (a PNG with its world file) in EPSG:3857."""
    layer = QgsRasterLayer(spec["path"], spec.get("name", "image"))
    if not layer.isValid():
        raise RuntimeError("invalid image " + spec["path"])
    layer.setCrs(QgsCoordinateReferenceSystem("EPSG:3857"))
    return layer


job = json.load(open(sys.argv[1], encoding="utf-8"))
out = sys.argv[2]
app = QgsApplication([], False)
app.initQgis()
crs = QgsCoordinateReferenceSystem("EPSG:3857")
x0, x1, y0, y1 = job["extent"]
extent = QgsRectangle(x0, y0, x1, y1)
w, h = job["size"]
dpi = job.get("dpi", 300)
land = job.get("land", "#f2efe9")
base = job["layers"][0]
streets_width = base.get("streets_width", 0.12)
basemap = shortbread_layer(base.get("water", "#aad3df"), land, base.get("streets"),
                           base.get("buildings"), base.get("border"))
groups = []                      # (is_image, [layers]) bottom to top
for spec in job["layers"][1:]:
    layer = image_layer(spec) if spec.get("type") == "raster" else vector_layer(spec)
    is_image = bool(spec.get("image"))
    if groups and groups[-1][0] == is_image:
        groups[-1][1].append(layer)
    else:
        groups.append((is_image, [layer]))
for layer in [basemap] + [l for _, ls in groups for l in ls]:
    QgsProject.instance().addMapLayer(layer, False)


def settings(layers, background):
    ms = QgsMapSettings()
    ms.setLayers(list(reversed(layers)))
    ms.setDestinationCrs(crs)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(extent)
    ms.setOutputSize(QSize(w, h))
    ms.setOutputDpi(dpi)
    ms.setBackgroundColor(background)
    return ms


def image(layers, background):
    job_ = QgsMapRendererParallelJob(settings(layers, background))
    loop = QEventLoop()
    job_.finished.connect(loop.quit)
    job_.start()
    loop.exec_()
    return job_.renderedImage()


pdf = QPdfWriter(out)
pdf.setResolution(dpi)
pdf.setPageSize(QPageSize(QSizeF(w / dpi * 25.4, h / dpi * 25.4), QPageSize.Millimeter))
pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
p = QPainter(pdf)
# The images are stored losslessly (Flate): JPEG, the default of an opaque image, would blur the
# thin streets with its artefacts
p.setRenderHint(QPainter.LosslessImageRendering, True)
p.drawImage(QRectF(0, 0, w, h), image([basemap], QColor(land)))
for is_image, layers in groups:
    if is_image:
        p.drawImage(QRectF(0, 0, w, h), image(layers, QColor(0, 0, 0, 0)))
    else:
        ms = settings(layers, QColor(0, 0, 0, 0))
        # Markers are otherwise cached as small images; this keeps every symbol a vector
        ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
        QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
p.end()
print("wrote", out)
app.exitQgis()
