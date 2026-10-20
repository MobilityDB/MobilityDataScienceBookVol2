"""Styles of the OpenMapTiles vector tiles of OpenFreeMap for Leaflet.VectorGrid, as #VectorTiles of the
book's figure helpers (vtiles.py of chapters 2 and 7) draws them.

#style_layers returns the background colour of a style and the JavaScript text of a function that, given
the Leaflet map, returns three VectorGrid styles drawn bottom to top: areas; road casings, waterways and
railways; road fills. Drawing the road fills in a grid above every casing keeps the casing of one tile
from crossing the road fill of its neighbour. The colours are those of the OpenFreeMap 'liberty' and 'positron' styles without their
symbol layers (no labels), each translucent fill blended over the background into an opaque colour,
so that the buffer of a tile may overlap its neighbour without darkening it.
"""
import json

STYLES = {
    "liberty": dict(background="#f8f4f0", water="#9ebdff", waterway="#a0c8f0", park="#e2ecd4",
                    residential="#f5ece0", wood="#e3efd4", grass="#e2ebd4", sand="#f7efc3",
                    aeroway="#ebe9e5", runway="#f0ede9", major="#ffeeaa", motorway="#ffcc88",
                    casing="#e9ac77", minor="#ffffff", rail="#bbbbbb", building="#dcd8d3"),
    "positron": dict(background="#f2f3f0", water="#c2c8ca", waterway="#c2c8ca", park="#e6ead9",
                     residential="#eaeaea", wood="#e6ead9", grass="#e6ead9", sand="#eeeee6",
                     aeroway="#e8e8e8", runway="#ffffff", major="#ffffff", motorway="#ffffff",
                     casing="#dddddd", minor="#ffffff", rail="#dddddd", building="#e4e4e4"),
}

# Every OpenMapTiles layer is given a style in each grid (an empty one when the grid does not draw it),
# since VectorGrid draws a layer without a style with the default Leaflet path style
_JS = """(map => {
  const c = %s;
  // a city map printed small (a style name ending in -city) leaves out, when the map is shown below
  // zoom 13, the road casings, the tertiary and minor roads and the residential areas, which it
  // would print below a pixel, and below zoom 14 the buildings, which it would print as
  // specks; the zoom is that of the map, the scale it prints at, not the zoom of its tiles, which
  // Leaflet rounds up from 12.5
  const city = %s;
  const coarse = z => city && map.getZoom() < 13;
  // beyond zoom 14, the most detailed level of the tiles, a tile is enlarged; its lines are drawn
  // thinner in proportion, so that they keep their width on the map
  const k = () => 2 ** Math.min(0, 14 - map.getZoom());
  const fill = col => ({fill: true, fillColor: col, fillOpacity: 1, stroke: true, color: col,
                        weight: 0.5 * k()});
  const line = (col, w) => ({fill: false, stroke: true, color: col, weight: w * k(),
                             lineCap: 'round', lineJoin: 'round'});
  const none = [];
  const road = p => p.brunnel === 'tunnel' ? null : p.class;
  const all = ['water', 'waterway', 'landcover', 'landuse', 'park', 'aeroway', 'building',
    'transportation', 'boundary', 'mountain_peak', 'water_name', 'transportation_name', 'place',
    'housenumber', 'poi', 'aerodrome_label', 'landmark'];
  const grids = [
    {water: p => p.brunnel === 'tunnel' ? none : fill(c.water),
     landcover: p => ({wood: fill(c.wood), grass: fill(c.grass), sand: fill(c.sand)})[p.class] || none,
     landuse: (p, z) => ({residential: coarse(z) ? none : fill(c.residential), cemetery: fill('#d8e0bd'),
       hospital: fill('#ffddee'), school: fill('#eceecc'), pitch: fill('#dee3cd'),
       track: fill('#dee3cd')})[p.class] || none,
     park: p => p.rank === undefined ? fill(c.park) : none,  // a park with a rank is a label point
     aeroway: fill(c.aeroway), building: () => city && map.getZoom() < 14 ? none : fill(c.building)},
    {waterway: p => p.brunnel === 'tunnel' ? none : line(c.waterway, 0.7),
     transportation: (p, z) => coarse(z) ? none : ({motorway: line(c.casing, 3.0), trunk: line(c.casing, 3.0),
       primary: line(c.casing, 3.0), secondary: line(c.casing, 2.2), tertiary: line(c.casing, 2.2),
       rail: line(c.rail, 0.5), transit: line(c.rail, 0.5)})[road(p)] || none},
    {transportation: (p, z) => ({motorway: line(c.motorway, 2.0), trunk: line(c.major, 2.0),
       primary: line(c.major, 2.0), secondary: line(c.major, 1.3),
       tertiary: coarse(z) ? none : line(c.major, 1.3),
       minor: z >= 13 && !coarse(z) ? line(c.minor, 1.0) : none})[road(p)] || none}];
  return grids.map(g => Object.fromEntries(all.map(n => [n, g[n] || none])));
})"""


def style_layers(style):
    """Background colour of `style` and JavaScript text of the function map -> three VectorGrid styles;
    `style` is a name of STYLES, or one followed by -city for a city map printed small."""
    base, city = (style[:-5], True) if style.endswith("-city") else (style, False)
    colours = STYLES[base]
    return colours["background"], _JS % (json.dumps(colours), json.dumps(city))
