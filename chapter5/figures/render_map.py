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

"""Render a map figure of the Rasters and Temporal Tessellations chapter.

Usage (from WSL):
  cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat" render_map.py job.json

The job file states the output, its size, the extent and the layers from bottom
to top. Land is the map background and the OSM Shortbread water layers are
drawn over it, since Shortbread has no land layer.
"""
import json
import sys

from qgis.core import (
    QgsApplication, QgsCoordinateReferenceSystem, QgsRectangle, QgsMapSettings,
    QgsMapRendererParallelJob, QgsRasterLayer, QgsVectorLayer, QgsVectorTileLayer,
    QgsVectorTileBasicRenderer, QgsVectorTileBasicRendererStyle, QgsFillSymbol,
    QgsLineSymbol, QgsMarkerSymbol, QgsSingleBandPseudoColorRenderer,
    QgsColorRampShader, QgsRasterShader, QgsWkbTypes, QgsPalLayerSettings,
    QgsTextFormat, QgsVectorLayerSimpleLabeling, QgsTextBufferSettings,
    QgsCoordinateTransform, QgsProject, Qgis)
from qgis.PyQt.QtCore import QSize, Qt, QRectF, QPointF
from qgis.PyQt.QtGui import QColor, QImage, QPainter, QFont, QLinearGradient, QPen, QFontDatabase

SHORTBREAD = ("type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/"
              "{z}/{x}/{y}.mvt&zmin=0&zmax=14")


def shortbread_layer(water, border):
    layer = QgsVectorTileLayer(SHORTBREAD, "shortbread")
    styles = []
    for name in ("ocean", "water_polygons"):
        st = QgsVectorTileBasicRendererStyle(name, name, QgsWkbTypes.PolygonGeometry)
        st.setSymbol(QgsFillSymbol.createSimple(
            {"color": water, "outline_style": "no"}))
        styles.append(st)
    for name in ("water_lines",):
        st = QgsVectorTileBasicRendererStyle(name, name, QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple({"color": water, "width": "0.2"}))
        styles.append(st)
    if border:
        st = QgsVectorTileBasicRendererStyle("boundaries", "boundaries",
                                             QgsWkbTypes.LineGeometry)
        st.setSymbol(QgsLineSymbol.createSimple(
            {"color": border, "width": "0.15", "line_style": "dash"}))
        styles.append(st)
    renderer = QgsVectorTileBasicRenderer()
    renderer.setStyles(styles)
    layer.setRenderer(renderer)
    return layer


def raster_layer(spec):
    layer = QgsRasterLayer(spec["path"], spec.get("name", "raster"))
    if not layer.isValid():
        raise RuntimeError("invalid raster " + spec["path"])
    ramp = QgsColorRampShader()
    ramp.setColorRampType(QgsColorRampShader.Interpolated)
    items = [QgsColorRampShader.ColorRampItem(v, QColor(c), str(v))
             for v, c in spec["ramp"]]
    ramp.setColorRampItemList(items)
    ramp.setClip(False)
    shader = QgsRasterShader()
    shader.setRasterShaderFunction(ramp)
    renderer = QgsSingleBandPseudoColorRenderer(layer.dataProvider(), 1, shader)
    layer.setRenderer(renderer)
    layer.renderer().setOpacity(spec.get("opacity", 1.0))
    return layer


def vector_layer(spec):
    uri = spec["path"] + ("|layername=" + spec["layer"] if "layer" in spec else "")
    layer = QgsVectorLayer(uri, spec.get("name", "vector"), "ogr")
    if not layer.isValid():
        raise RuntimeError("invalid vector " + uri)
    if "filter" in spec:
        layer.setSubsetString(spec["filter"])
    kind = spec.get("kind", "fill")
    if kind == "fill":
        sym = QgsFillSymbol.createSimple(spec["style"])
    elif kind == "line":
        sym = QgsLineSymbol.createSimple(spec["style"])
    else:
        sym = QgsMarkerSymbol.createSimple(spec["style"])
    if layer.renderer() is not None:
        layer.renderer().setSymbol(sym)
    if "label" in spec:
        lab = QgsPalLayerSettings()
        lab.fieldName = spec["label"]["field"]
        lab.isExpression = spec["label"].get("expression", False)
        fmt = QgsTextFormat()
        fmt.setFont(QFont(spec["label"].get("font", "Arial")))
        fmt.setSize(spec["label"].get("size", 8))
        fmt.setColor(QColor(spec["label"].get("color", "#000000")))
        buf = QgsTextBufferSettings()
        buf.setEnabled(spec["label"].get("buffer", True))
        buf.setSize(0.8)
        buf.setColor(QColor("#ffffff"))
        fmt.setBuffer(buf)
        lab.setFormat(fmt)
        if "placement" in spec["label"]:
            lab.placement = getattr(Qgis.LabelPlacement, spec["label"]["placement"])
        if spec["label"].get("display_all", False):
            lab.displayAll = True
        if "quadrant" in spec["label"]:
            lab.quadOffset = getattr(Qgis.LabelQuadrantPosition, spec["label"]["quadrant"])
        if "distance" in spec["label"]:
            lab.dist = spec["label"]["distance"]
        layer.setLabeling(QgsVectorLayerSimpleLabeling(lab))
        layer.setLabelsEnabled(True)
    return layer


def draw_colorbar(painter, spec, width, height):
    x, y, w, h = spec["rect"]
    x *= width; y *= height; w *= width; h *= height
    if spec.get("background"):
        # A white box behind the title, the bar, and the ticks, for a bar drawn over the map
        fpx = int(spec.get("font_px", 26))
        painter.fillRect(QRectF(x - fpx * 0.8, y - fpx * 1.6, w + fpx * 1.6, h + fpx * 3.1),
                         QColor(255, 255, 255, 220))
    grad = QLinearGradient(QPointF(x, y), QPointF(x + w, y))
    vmin = spec["ramp"][0][0]; vmax = spec["ramp"][-1][0]
    for v, c in spec["ramp"]:
        grad.setColorAt((v - vmin) / (vmax - vmin), QColor(c))
    painter.fillRect(QRectF(x, y, w, h), grad)
    painter.setPen(QPen(QColor("#333333"), 1))
    painter.drawRect(QRectF(x, y, w, h))
    font = QFont(spec.get("font", "Arial"))
    font.setPixelSize(int(spec.get("font_px", 26)))
    painter.setFont(font)
    for v in spec["ticks"]:
        tx = x + (v - vmin) / (vmax - vmin) * w
        painter.drawLine(QPointF(tx, y + h), QPointF(tx, y + h + 8))
        text = str(v)
        adv = painter.fontMetrics().horizontalAdvance(text)
        painter.drawText(QPointF(tx - adv / 2, y + h + 8 + font.pixelSize()), text)
    title = spec.get("title", "")
    if title:
        painter.drawText(QPointF(x, y - 10), title)


def draw_legend(painter, spec, width, height):
    x, y = spec["origin"]
    x *= width; y *= height
    font = QFont(spec.get("font", "Arial"))
    font.setPixelSize(int(spec.get("font_px", 26)))
    painter.setFont(font)
    box = font.pixelSize()
    step = int(box * 1.5)
    rows = spec["items"]
    title = spec.get("title", "")
    pad = box // 2
    text_w = max(painter.fontMetrics().horizontalAdvance(t) for t, _ in rows)
    title_w = painter.fontMetrics().horizontalAdvance(title) if title else 0
    top = y - (step if title else 0)
    frame_h = (step if title else 0) + step * len(rows)
    painter.fillRect(QRectF(x - pad, top - pad, max(box + pad + text_w, title_w) + 2 * pad,
                            frame_h + pad), QColor(255, 255, 255, 220))
    painter.setPen(QPen(QColor("#333333"), 1))
    if title:
        painter.drawText(QPointF(x, top + box), title)
    for i, (label, color) in enumerate(rows):
        ry = y + i * step
        painter.fillRect(QRectF(x, ry, box, box), QColor(color))
        painter.drawRect(QRectF(x, ry, box, box))
        painter.drawText(QPointF(x + box + pad, ry + box - 3), label)


def main(job_path):
    job = json.load(open(job_path, encoding="utf-8"))
    qgs = QgsApplication([], False)
    qgs.initQgis()
    for path in job.get("fonts", []):
        # A font file of the job, such as the font of the book the figure is printed in
        fid = QFontDatabase.addApplicationFont(path)
        if fid < 0:
            raise RuntimeError("invalid font " + path)
        print("font", path, QFontDatabase.applicationFontFamilies(fid))
    crs = QgsCoordinateReferenceSystem(job["crs"])
    layers = []
    for spec in job["layers"]:
        if spec["type"] == "shortbread":
            layers.append(shortbread_layer(spec.get("water", "#c6dcef"),
                                           spec.get("border")))
        elif spec["type"] == "raster":
            layers.append(raster_layer(spec))
        else:
            layers.append(vector_layer(spec))
    for layer in layers:
        QgsProject.instance().addMapLayer(layer, False)
    settings = QgsMapSettings()
    settings.setDestinationCrs(crs)
    settings.setTransformContext(QgsProject.instance().transformContext())
    settings.setLayers(list(reversed(layers)))
    xmin, ymin, xmax, ymax = job["extent"]
    extent = QgsRectangle(xmin, ymin, xmax, ymax)
    if job.get("extent_crs") and job["extent_crs"] != job["crs"]:
        tr = QgsCoordinateTransform(QgsCoordinateReferenceSystem(job["extent_crs"]),
                                    crs, QgsProject.instance())
        extent = tr.transformBoundingBox(extent)
    settings.setExtent(extent)
    width, height = job["size"]
    settings.setOutputSize(QSize(width, height))
    settings.setOutputDpi(job.get("dpi", 300))
    settings.setBackgroundColor(QColor(job.get("land", "#f2efe9")))
    render = QgsMapRendererParallelJob(settings)
    render.start()
    render.waitForFinished()
    img = render.renderedImage()
    if "colorbar" in job or "legend" in job:
        out = QImage(img)
        painter = QPainter(out)
        painter.setRenderHint(QPainter.Antialiasing)
        if "colorbar" in job:
            draw_colorbar(painter, job["colorbar"], width, height)
        if "legend" in job:
            draw_legend(painter, job["legend"], width, height)
        painter.end()
        img = out
    img.save(job["output"], "PNG")
    print("wrote", job["output"], width, height)
    qgs.exitQgis()


if __name__ == "__main__":
    main(sys.argv[1])
