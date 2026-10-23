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

# Renders a map figure of the book with PyQGIS over OSM Shortbread vector tiles, whose labels are not drawn
#   python3 render_spec.py <spec.json>     (a Python with PyQGIS, e.g. python-qgis-ltr.bat on Windows)
# The spec names the GeoJSON (features carry a "layer" property), the output (a PNG, or a PDF whose
# basemap and data layers are all vectors), its pixel size, the
# extent (bbox [lon1, lat1, lon2, lat2], or center [lon, lat] with half_m, the half width in metres),
# and the data layers from top to bottom, each with a type (fill, line, point) and its colours.
# A layer may instead name a QML style ("qml"), the style of the layer in the QGIS project of the figure,
# which then draws its symbols and the labels of its features; the OSM layer draws no labels. "extent"
# gives the extent in the map CRS "crs" (default EPSG:3857), "dpi" the output resolution (default 300),
# and "flip" stores the image upside down, as an image that a PDF places with a negative vertical scale.
# "labels_out" writes the labels of the QML styles to a JSON file for a LaTeX overlay and draws the figure
# without them; "label_pt" then gives the size, in points of the figure, at which the labels are placed
# (the printed size of the overlay's font divided by the scale at which the figure is printed), and a layer
# with "label_unplaced" also gets a label for each of its features that the engine left out. The labels are
# placed in the regular face of their font, as \captionstyle sets them, and "label_priority" of a layer
# (0 to 10, default 5, or an expression over the fields of a feature) places its labels before those of
# lower priority, "label_placement" (a member of Qgis.LabelPlacement) replaces the placement of its style,
# and "label_obstacle" the weight of its features as obstacles to the other labels (0: none).
# "label_font" names a font file (fonts/lmroman9-regular.otf, the face of \captionstyle at 8.5 pt) in which
# the labels are placed, so that the engine measures them as LaTeX sets them.
# A layer with "image" true is drawn in a PDF as one lossless image of the pixels of the figure as the book
# prints it at 300 dpi, "print_width_mm" wide, between the vector layers below and above it, so that a dense
# layer costs a viewer one image and no viewer resamples it.
import sys, os, json, math
from qgis.core import (QgsRenderContext, QgsMapRendererCustomPainterJob, Qgis, QgsPalLayerSettings, QgsVectorLayerSimpleLabeling, QgsApplication, QgsVectorLayer, QgsMapSettings, QgsMapRendererParallelJob,
    QgsCoordinateReferenceSystem, QgsRectangle, QgsProject, QgsCoordinateTransform, QgsPointXY,
    QgsSingleSymbolRenderer, QgsWkbTypes, QgsGeometry, QgsMarkerSymbol, QgsLineSymbol, QgsFillSymbol,
    QgsVectorTileLayer, QgsVectorTileBasicRenderer, QgsVectorTileBasicRendererStyle, QgsProperty)
from qgis.PyQt.QtCore import QSize, QSizeF, QMarginsF, QEventLoop, QRectF
from qgis.PyQt.QtGui import QColor, QPainter, QPdfWriter, QPageSize, QFontDatabase, QImage

spec = json.load(open(sys.argv[1]))
base = os.path.dirname(os.path.abspath(sys.argv[1]))
src = os.path.join(base, spec['geojson'])
app = QgsApplication([], False); app.initQgis()
label_family = None
if 'label_font' in spec:
    fid = QFontDatabase.addApplicationFont(os.path.join(base, spec['label_font']))
    if fid < 0:
        sys.exit('font ' + spec['label_font'])
    label_family = QFontDatabase.applicationFontFamilies(fid)[0]
    print('label font', label_family)
merc = QgsCoordinateReferenceSystem(spec.get('crs', 'EPSG:3857'))
wgs = QgsCoordinateReferenceSystem('EPSG:4326')

LAND, WATER = '#f2efe9', '#aad3df'
osm = QgsVectorTileLayer(
    'type=xyz&url=https://vector.openstreetmap.org/shortbread_v1/{z}/{x}/{y}.mvt&zmin=0&zmax=14', 'osm')
styles = []
for lname, geom, sym in [
        ('ocean', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.3'})),
        ('water_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': WATER, 'outline_color': WATER, 'outline_width': '0.3'})),
        ('buildings', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': '#d9d0c9', 'outline_color': '#c4b6ab', 'outline_width': '0.1'})),
        ('pier_polygons', QgsWkbTypes.PolygonGeometry,
         QgsFillSymbol.createSimple({'color': '#b0b0b0', 'outline_color': '#909090', 'outline_width': '0.1'})),
        ('pier_lines', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': '#a0a0a0', 'line_width': '1.2', 'capstyle': 'round'})),
        ('streets', QgsWkbTypes.LineGeometry,
         QgsLineSymbol.createSimple({'line_color': '#ffffff', 'line_width': '0.35'}))]:
    st = QgsVectorTileBasicRendererStyle(lname, lname, geom)
    st.setSymbol(sym)
    styles.append(st)
vtr = QgsVectorTileBasicRenderer(); vtr.setStyles(styles); osm.setRenderer(vtr)

def symbol(l):
    t = l['type']
    if t == 'point':
        return QgsMarkerSymbol.createSimple({'name': 'circle', 'color': l['color'],
            'outline_color': l.get('outline', '#000000'), 'outline_width': str(l.get('outline_width', 0.2)),
            'size': str(l.get('size', 2.0))})
    if t == 'line':
        return QgsLineSymbol.createSimple({'line_color': l['color'], 'line_width': str(l.get('width', 0.4)),
            'line_style': l.get('style', 'solid'), 'capstyle': 'round'})
    return QgsFillSymbol.createSimple({'color': l['color'], 'outline_color': l.get('outline', '#000000'),
        'outline_width': str(l.get('outline_width', 0.2))})

layers = []
for l in spec['layers']:
    lyr = QgsVectorLayer(src, l['name'], 'ogr')
    lyr.setSubsetString(f"\"layer\" = '{l['name']}'")
    if lyr.featureCount() == 0:
        print('empty layer', l['name']); continue
    if 'qml' in l:
        msg, ok = lyr.loadNamedStyle(os.path.join(base, l['qml']))
        if not ok:
            sys.exit('style ' + l['qml'] + ': ' + msg)
    else:
        lyr.setRenderer(QgsSingleSymbolRenderer(symbol(l)))
    if lyr.opacity() < 1:  # the opacity of the layer goes to its symbols, which a PDF keeps as vectors
        for sym in lyr.renderer().symbols(QgsRenderContext()):
            sym.setOpacity(sym.opacity() * lyr.opacity())
        lyr.setOpacity(1)
    lyr.setCustomProperty('label_unplaced', bool(l.get('label_unplaced')))
    lyr.setCustomProperty('image', bool(l.get('image')))
    if 'label_pt' in spec and lyr.labelsEnabled() and lyr.labeling() is not None:
        pal = lyr.labeling().settings()  # the labels are placed at the size they are printed in the overlay
        if pal.drawLabels:
            fmt = pal.format(); fmt.setSize(spec['label_pt']); fmt.setSizeUnit(Qgis.RenderUnit.Points)
            font = fmt.font(); font.setBold(False)  # the regular face of \captionstyle
            if label_family:
                font.setFamily(label_family)
            fmt.setFont(font); fmt.setForcedBold(False); fmt.setNamedStyle('Regular')
            pal.setFormat(fmt)
            if 'label_obstacle' in l:  # the weight of the features as obstacles to other labels, 0 for none
                pal.obstacleSettings().setIsObstacle(l['label_obstacle'] > 0)
                pal.obstacleSettings().setFactor(l['label_obstacle'])
            if 'label_placement' in l:  # a member of Qgis.LabelPlacement, e.g. Horizontal (anywhere inside)
                pal.placement = getattr(Qgis.LabelPlacement, l['label_placement'])
            if 'label_priority' in l:  # 0 (lowest) to 10, the labels of the higher placed first
                if isinstance(l['label_priority'], str):  # an expression over the fields of the feature
                    pal.dataDefinedProperties().setProperty(QgsPalLayerSettings.Priority,
                                                            QgsProperty.fromExpression(l['label_priority']))
                else:
                    pal.priority = l['label_priority']
            lyr.setLabeling(QgsVectorLayerSimpleLabeling(pal))
    if l.get('obstacle'):  # the labels of the other layers are kept off the features of this one
        pal = QgsPalLayerSettings()
        pal.drawLabels = False  # the features are only obstacles
        pal.obstacleSettings().setIsObstacle(True)
        # the weight of the obstacle, 0 to 2: true is 1; a lower one lets the labels of high priority cross it
        pal.obstacleSettings().setFactor(1 if l["obstacle"] is True else l["obstacle"])
        lyr.setLabeling(QgsVectorLayerSimpleLabeling(pal))
        lyr.setLabelsEnabled(True)
    layers.append(lyr)
layers.append(osm)

tr = QgsCoordinateTransform(wgs, merc, QgsProject.instance())
w = spec.get('width', 1800)
if 'extent' in spec:
    rect = QgsRectangle(*spec['extent'])
    h = spec['height']
elif 'bbox' in spec:
    x1, y1, x2, y2 = spec['bbox']
    ll = tr.transform(QgsPointXY(x1, y1)); ur = tr.transform(QgsPointXY(x2, y2))
    rect = QgsRectangle(ll.x(), ll.y(), ur.x(), ur.y())
    h = spec.get('height', round(w * rect.height() / rect.width()))
    if 'height' in spec:  # widen the shorter side to the requested aspect
        cx, cy = rect.center().x(), rect.center().y()
        hw, hh = rect.width() / 2, rect.height() / 2
        if hw / hh < w / h: hw = hh * w / h
        else: hh = hw * h / w
        rect = QgsRectangle(cx - hw, cy - hh, cx + hw, cy + hh)
else:
    lon, lat = spec['center']
    c = tr.transform(QgsPointXY(lon, lat))
    hw = spec['half_m'] / math.cos(math.radians(lat))
    h = spec.get('height', w)
    rect = QgsRectangle(c.x() - hw, c.y() - hw * h / w, c.x() + hw, c.y() + hw * h / w)

dpi = spec.get('dpi', 300)


def settings(lyrs, px, py, d):
    """The map settings of the figure."""
    ms = QgsMapSettings()
    ms.setLayers(lyrs); ms.setDestinationCrs(merc); ms.setExtent(rect)
    ms.setTransformContext(QgsProject.instance().transformContext())
    ms.setOutputSize(QSize(px, py)); ms.setOutputDpi(d)
    ms.setBackgroundColor(QColor(LAND))
    les = ms.labelingEngineSettings()  # a label is placed whole inside the figure or not at all
    les.setFlag(Qgis.LabelingFlag.UsePartialCandidates, False)
    ms.setLabelingEngineSettings(les)
    return ms


def render(ms):
    """The image of the map settings."""
    job = QgsMapRendererParallelJob(ms); loop = QEventLoop()
    job.finished.connect(loop.quit); job.start(); loop.exec_()
    return job.renderedImage()


out = os.path.join(base, spec['out'])
if 'labels_out' in spec:
    # The labels of the QML styles are placed by the labelling engine on an image of the figure and written
    # to "labels_out" (JSON: text and centre of each label, as fractions of the figure width and height
    # from its lower left corner, with the style of its layer: the text colour, the shape and fill colour of
    # its background, and the angle of its baseline in degrees counterclockwise), for a LaTeX overlay to set
    # them; the figure itself is drawn without them.
    job = QgsMapRendererParallelJob(settings(layers, w, h, dpi)); loop = QEventLoop()
    job.finished.connect(loop.quit); job.start(); loop.exec_()
    by_id = {lyr.id(): lyr for lyr in layers}

    def label_style(lyr):
        """The style of the labels of the layer as the overlay sets it. The reverse of #symbol, which
        makes a symbol from the colours of a spec layer."""
        fmt = lyr.labeling().settings().format()
        st = {'layer': lyr.name(), 'color': fmt.color().name()[1:].upper()}
        bg = fmt.background()
        if bg.enabled():
            fill = bg.fillSymbol().color() if bg.fillSymbol() else bg.fillColor()
            st['shape'] = 'circle' if bg.type() == bg.ShapeCircle else 'rect'
            st['fill'] = fill.name()[1:].upper()
        return st

    labels = []
    for lp in job.takeLabelingResults().allLabels():
        c = lp.labelRect.center()
        lab = {'text': lp.labelText, 'x': (c.x() - rect.xMinimum()) / rect.width(),
               'y': (c.y() - rect.yMinimum()) / rect.height()}
        lab.update(label_style(by_id[lp.layerID]))
        p0, p1 = lp.cornerPoints[0], lp.cornerPoints[1]  # the baseline, from its start to its end
        a = math.degrees(math.atan2(p1.y() - p0.y(), p1.x() - p0.x()))
        if a > 90:
            a -= 180
        elif a <= -90:
            a += 180
        if abs(a) > 0.5:
            lab['angle'] = round(a, 1)
        labels.append(lab)
    # A feature in the figure whose label the engine left out (it found no free position at the label size
    # of the style) is labelled at the pole of inaccessibility of its part inside the figure, in a layer
    # with "label_unplaced"
    placed = {l['text'] for l in labels}
    for lyr in layers:
        if lyr is osm or not lyr.labelsEnabled() or lyr.labeling() is None \
                or not lyr.customProperty('label_unplaced'):
            continue
        field = lyr.labeling().settings().fieldName
        to_map = QgsCoordinateTransform(lyr.crs(), merc, QgsProject.instance())
        for f in lyr.getFeatures():
            text = str(f[field])
            g = f.geometry(); g.transform(to_map)
            g = g.intersection(QgsGeometry.fromRect(rect))
            if text in placed or g.isEmpty():
                continue
            p = g.poleOfInaccessibility(rect.width() / 1000)[0].asPoint()
            lab = {'text': text, 'x': (p.x() - rect.xMinimum()) / rect.width(),
                   'y': (p.y() - rect.yMinimum()) / rect.height(), 'unplaced': True}
            lab.update(label_style(lyr))
            labels.append(lab)
    labels.sort(key=lambda l: (-l['y'], l['x']))
    json.dump(labels, open(os.path.join(base, spec['labels_out']), 'w'), indent=1)
    for lyr in layers:
        if lyr is not osm:
            lyr.setLabelsEnabled(False)
if out.endswith('.pdf'):
    # Every layer a vector, the basemap and the data layers drawn in one job over the land on a page of the physical size of the figure (pixels / dpi)
    pdf = QPdfWriter(out); pdf.setResolution(dpi)
    pdf.setPageSize(QPageSize(QSizeF(w / dpi * 25.4, h / dpi * 25.4), QPageSize.Millimeter))
    pdf.setPageMargins(QMarginsF(0, 0, 0, 0))
    p = QPainter(pdf)
    ms = settings(layers, w, h, dpi)
    # Markers and vector tiles are otherwise cached as images; this keeps every symbol a vector
    ms.setFlag(QgsMapSettings.ForceVectorOutput, True)
    # The frame of the page, from which the tile edges of the basemap are found
    print('frame', merc.authid(), rect.xMinimum(), rect.yMinimum(), rect.xMaximum(), rect.yMaximum(),
          w, h, 'scale', ms.scale(), 'zoom', osm.tileMatrixSet().scaleToZoomLevel(ms.scale()))
    if 'print_width_mm' not in spec or not any(l.customProperty('image') for l in layers):
        QgsMapRendererCustomPainterJob(ms, p).renderSynchronously()
    else:
        # The runs of layers from the bottom up: a run of vector layers drawn as vectors, a run of image layers
        # as one image of the printed pixels; the land is the background of the bottom run only
        iw = round(spec['print_width_mm'] / 25.4 * 300); ih = round(iw * h / w)
        runs = []
        for lyr in reversed(layers):
            if runs and bool(lyr.customProperty('image')) == bool(runs[-1][0].customProperty('image')):
                runs[-1].append(lyr)
            else:
                runs.append([lyr])
        for i, run in enumerate(runs):
            image = bool(run[0].customProperty('image'))
            s = settings(list(reversed(run)), iw if image else w, ih if image else h, dpi * iw / w if image else dpi)
            if i > 0:
                s.setBackgroundColor(QColor(0, 0, 0, 0))
            if image:
                img = QImage(iw, ih, QImage.Format_ARGB32); img.fill(s.backgroundColor())
                ip = QPainter(img)
                QgsMapRendererCustomPainterJob(s, ip).renderSynchronously()
                ip.end()
                p.save(); p.setRenderHint(QPainter.LosslessImageRendering)
                p.drawImage(QRectF(0, 0, w, h), img)
                p.restore()
            else:
                s.setFlag(QgsMapSettings.ForceVectorOutput, True)
                QgsMapRendererCustomPainterJob(s, p).renderSynchronously()
    p.end()
else:
    img = render(settings(layers, w, h, dpi))
    if spec.get('flip'):
        img = img.mirrored(False, True)
    img.save(out)
print('wrote', out, w, h)
app.exitQgis()
