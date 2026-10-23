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
