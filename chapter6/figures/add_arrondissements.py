# Adds the arrondissements of Paris (Paris open data, dataset "arrondissements", ODbL) to the layers of
# the figure s-m-itinerary as the layer "arrondissements", with the name of each arrondissement in the
# field Nom_de_larr that the style qml/paris_arr.qml labels.
#   python3 add_arrondissements.py arrondissements.geojson paris_poi.geojson smi.geojson
import json
import sys

arr = json.load(open(sys.argv[1]))
fc = json.load(open(sys.argv[2]))
for f in arr['features']:
    fc['features'].append({'type': 'Feature', 'geometry': f['geometry'],
                           'properties': {'layer': 'arrondissements',
                                          'Nom_de_larr': f['properties']['l_ar']}})
json.dump(fc, open(sys.argv[3], 'w'))
print('wrote', sys.argv[3], len(fc['features']), 'features')
