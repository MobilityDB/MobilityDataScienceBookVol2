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

"""Render a map figure with QGIS as a PDF: basemap image, data layers as vectors.

This is chapter8/figures/qgis_map.py of the companion repository with the CRS of the map
("crs", EPSG:3857 by default) and the width, style and administrative level of the borders
("border_width", "border_style", "border_admin_level", "border_land_only" of the basemap), the
smallest area of the water polygons drawn ("water_min_area", in square meters), whether the
rivers are drawn ("water_lines") and the oversampling of the basemap ("basemap_oversample")
read from the job, and with the texts of the job ("texts", see #draw_text) drawn as vectors over
the layers.

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
from qgis.PyQt.QtCore import Qt, QSize, QSizeF, QRectF, QMarginsF, QEventLoop
from qgis.PyQt.QtGui import (QColor, QPainter, QPdfWriter, QPageSize, QFont, QFontMetricsF,
                             QPainterPath, QPen)

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
            {"color": water, "outline_color": water, "outline_width": str(0.1 * oversample)}))
        if name == "water_polygons" and water_min_area:
            st.setFilterExpression(f'"way_area" > {water_min_area}')
        styles.append(st)
    if water_lines:
        st = QgsVectorTileBasicRendererStyle("water_lines", "water_lines", QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple({"color": water, "width": str(0.2 * oversample)}))
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
        st.setSymbol(QgsLineSymbol.createSimple({"color": streets, "width": str(streets_width * oversample)}))
        styles.append(st)
    if border:
        st = QgsVectorTileBasicRendererStyle("boundaries", "boundaries", QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple(
            {"color": border, "width": str(border_width * oversample), "line_style": border_style}))
        conds = []
        if border_admin_level:
            conds.append(f'"admin_level" = {border_admin_level}')
        if border_land_only:
            conds.append('coalesce("maritime", 0) = 0')
        if conds:
            st.setFilterExpression(" AND ".join(conds))
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
crs = QgsCoordinateReferenceSystem(job.get("crs", "EPSG:3857"))
x0, x1, y0, y1 = job["extent"]
extent = QgsRectangle(x0, y0, x1, y1)
w, h = job["size"]
dpi = job.get("dpi", 300)
land = job.get("land", "#f2efe9")
base = job["layers"][0]
streets_width = base.get("streets_width", 0.12)
border_width = base.get("border_width", 0.15)
border_style = base.get("border_style", "dash")
border_admin_level = base.get("border_admin_level")
border_land_only = base.get("border_land_only", False)
water_min_area = base.get("water_min_area")
water_lines = base.get("water_lines", True)
# The basemap is drawn oversample times larger, so that QGIS takes the tiles of a finer zoom
# level, with its lines as many times wider, and scaled down to the size of the figure
oversample = job.get("basemap_oversample", 1)
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


def settings(layers, background, k=1):
    ms = QgsMapSettings()
    ms.setLayers(list(reversed(layers)))
    ms.setDestinationCrs(crs)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setExtent(extent)
    ms.setOutputSize(QSize(w * k, h * k))
    ms.setOutputDpi(dpi)
    ms.setBackgroundColor(background)
    return ms


def image(layers, background, k=1):
    job_ = QgsMapRendererParallelJob(settings(layers, background, k))
    loop = QEventLoop()
    job_.finished.connect(loop.quit)
    job_.start()
    loop.exec_()
    return job_.renderedImage()


def draw_text(painter, t):
    """Draw the text t["text"] as vectors at the point (t["x"], t["y"]) of the map, on the side
    t["anchor"] of the point ("above", "left" or "right") at t["gap"] points from it, in the
    font t["font"] of t["size"] points, black with a thin halo of the land color.
    @details No sibling: qgis_map.py draws no text (its basemap carries no label), and this
    routine is built beside #vector_layer, which draws the other layers of the job"""
    px = (t["x"] - x0) / (x1 - x0) * w
    py = (y1 - t["y"]) / (y1 - y0) * h
    font = QFont(t.get("font", "Arial"))
    # A path takes the font in device pixels, so the size in points is converted at the dpi
    font.setPixelSize(round(t.get("size", 10) / 72 * dpi))
    fm = QFontMetricsF(font, pdf)
    tw, asc, desc = fm.horizontalAdvance(t["text"]), fm.ascent(), fm.descent()
    gap = t.get("gap", 2) / 72 * dpi
    anchor = t.get("anchor", "above")
    if anchor == "above":
        bx, by = px - tw / 2, py - gap - desc
    elif anchor == "left":
        bx, by = px - gap - tw, py + (asc - desc) / 2
    else:
        bx, by = px + gap, py + (asc - desc) / 2
    path = QPainterPath()
    path.addText(bx, by, font, t["text"])
    painter.setRenderHint(QPainter.Antialiasing, True)
    painter.strokePath(path, QPen(QColor(land), 0.8 / 72 * dpi, Qt.SolidLine, Qt.RoundCap,
                                  Qt.RoundJoin))
    painter.fillPath(path, QColor(t.get("color", "#000000")))


pdf = QPdfWriter(out)
pdf.setResolution(dpi)
pdf.setPageSize(QPageSize(QSizeF(w / dpi * 25.4, h / dpi * 25.4), QPageSize.Millimeter))
pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
p = QPainter(pdf)
# The images are stored losslessly (Flate): JPEG, the default of an opaque image, would blur the
# thin streets with its artefacts
p.setRenderHint(QPainter.LosslessImageRendering, True)
p.drawImage(QRectF(0, 0, w, h), image([basemap], QColor(land), oversample).scaled(
    w, h, Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
for is_image, layers in groups:
    if is_image:
        p.drawImage(QRectF(0, 0, w, h), image(layers, QColor(0, 0, 0, 0)))
    else:
        ms = settings(layers, QColor(0, 0, 0, 0))
        # Markers are otherwise cached as small images; this keeps every symbol a vector
        ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
        QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
for t in job.get("texts", []):
    draw_text(p, t)
p.end()
print("wrote", out)
app.exitQgis()
