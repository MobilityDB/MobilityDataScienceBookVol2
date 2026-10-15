# Extracts the style of a layer of a QGIS project (.qgs) as a QML file: the symbology, the labels,
# the opacity and the blending of the <maplayer> element, without its data source.
#   python3 extract_qml.py project.qgs "layer name" out.qml
import sys
import xml.etree.ElementTree as ET

KEEP = {'renderer-v2', 'labeling', 'blendMode', 'featureBlendMode', 'layerOpacity', 'customproperties',
        'geometryOptions', 'previewExpression', 'mapTip', 'selection', 'diagramlayerobject',
        'SingleCategoryDiagramRenderer', 'DiagramLayerSettings', 'fieldConfiguration', 'aliases',
        'defaults', 'constraints'}
qgs, name, out = sys.argv[1:4]
root = ET.parse(qgs).getroot()
for ml in root.iter('maplayer'):
    if ml.findtext('layername') == name:
        break
else:
    sys.exit('no layer ' + name)
q = ET.Element('qgis', {'version': root.get('version', '3.40'), 'styleCategories': 'AllStyleCategories',
                        'labelsEnabled': ml.get('labelsEnabled', '0')})
for child in ml:
    if child.tag in KEEP:
        q.append(child)
ET.ElementTree(q).write(out, encoding='unicode')
print('wrote', out)
