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
