# Writes the QML styles of the chapter 6 figures that have no QGIS project: the districts of Delhi,
# categorized by name and labeled with it, the trips labeled with their identifier in a white
# circle, and the points of interest of Paris categorized by category. Each style is derived from
# the style of a layer of a QGIS project of the chapter (extracted by extract_qml.py into qml/) so
# that the symbols and the labels keep the look of the other figures; render_spec.py makes only
# single symbols, so the categorized and labeled styles come from these templates.
#   python3 make_qml.py
import copy
import os
import xml.etree.ElementTree as ET

QML = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'qml') + os.sep


def opt(elem, name, value):
    for o in elem.iter('Option'):
        if o.get('name') == name:
            o.set('value', value)


def categorized(template, out, field, cats, label_field=None, label_color=None, opacity=None,
                outline=None, outline_width=None, size=None, label_size=None):
    """cats: list of (value, 'r,g,b,a'); the first symbol of the template is cloned for each."""
    root = ET.parse(QML + template).getroot()
    rv = root.find('renderer-v2')
    rv.set('attr', field)
    proto = rv.find('symbols')[0]
    cel, sel = rv.find('categories'), rv.find('symbols')
    for e in list(cel):
        cel.remove(e)
    for e in list(sel):
        sel.remove(e)
    for i, (value, color) in enumerate(cats):
        ET.SubElement(cel, 'category', {'value': value, 'symbol': str(i), 'label': value, 'render': 'true',
                                        'type': 'string', 'uuid': f'c{i}'})
        s = copy.deepcopy(proto)
        s.set('name', str(i))
        s.set('alpha', '1')
        opt(s, 'color', color)
        if outline:
            opt(s, 'outline_color', outline)
        if outline_width:
            opt(s, 'outline_width', outline_width)
        if size:
            opt(s, 'size', size)
        sel.append(s)
    if opacity is not None:
        root.find('layerOpacity').text = str(opacity)
    if label_field:
        ts = root.find('.//text-style')
        ts.set('fieldName', label_field)
        if label_color:
            ts.set('textColor', label_color)
        if label_size:
            ts.set('fontSize', label_size)
    ET.ElementTree(root).write(QML + out, encoding='unicode')
    print('wrote', QML + out)


def trip_line(template, out, color, width, label_size=None):
    """A trip drawn as a line and labeled with its identifier in a white circle."""
    root = ET.parse(QML + template).getroot()
    rv = root.find('renderer-v2')
    for layer in rv.iter('layer'):
        opt(layer, 'line_color', color)
        opt(layer, 'line_width', width)
    bg = root.find('.//background')
    bg.set('shapeType', '3')
    bg.set('shapeFillColor', '255,255,255,255')
    opt(bg, 'color', '255,255,255,255')  # the fill symbol of the background
    root.find('.//placement').set('placement', '4')  # horizontal, as the cell numbers
    if label_size:
        root.find('.//text-style').set('fontSize', label_size)
    ET.ElementTree(root).write(QML + out, encoding='unicode')
    print('wrote', QML + out)


# Districts of Delhi, figure griddistricts
categorized('paris_arr.qml', 'gd_districts.qml', 'name', [
    ('North Delhi', '232,110,90,255'), ('North West Delhi', '80,200,170,255'),
    ('West Delhi', '150,215,120,255'), ('South West Delhi', '240,225,90,255'),
    ('New Delhi', '200,150,80,255'), ('Central Delhi', '215,80,110,255'),
    ('Shahdara', '200,110,180,255'), ('East Delhi', '100,80,210,255'),
    ('North East Delhi', '200,150,220,255'), ('South East Delhi', '230,110,40,255'),
    ('South Delhi', '230,130,170,255')],
    label_field='name', label_color='50,50,50,255', opacity=0.35, outline='90,90,140,255',
    outline_width='0.3', label_size='16')
# Districts of Delhi, figures alternate and development
categorized('paris_arr.qml', 'alt_districts.qml', 'name', [
    ('New Delhi', '230,230,40,255'), ('South East Delhi', '150,215,90,255'),
    ('Central Delhi', '40,110,220,255'), ('South Delhi', '230,230,40,255'),
    ('Shahdara', '210,150,210,255'), ('East Delhi', '100,90,220,255')],
    label_field='name', label_color='50,50,50,255', opacity=0.45, outline='50,50,50,255',
    outline_width='0.3', label_size='16')
trip_line('t6_line.qml', 'trip_orange.qml', '230,100,50,255', '0.86', label_size='14')
trip_line('t6_line.qml', 'trip_blue.qml', '33,14,244,255', '0.86', label_size='14')
trip_line('t6_line.qml', 'trip_blue_thin.qml', '33,14,244,255', '0.36')
# Points of interest of Paris, figure s-m-Itinerary
categorized('paris_pois.qml', 'smi_pois.qml', 'category', [
    ('Hotel', '240,150,50,255'), ('Restaurant', '90,200,110,255'), ('Museum', '240,240,30,255')],
    label_field='name')
