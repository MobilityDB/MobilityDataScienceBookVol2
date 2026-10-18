"""Printing of the Folium maps of the book whose basemap is #VectorTiles (Leaflet.VectorGrid, SVG), and the
TikZ overlay that carries the text the map image does not show.

#print_map prints with headless Chrome at device scale 2 a PDF page of a given size scaled from the CSS
layout. The extent (view or bounds) is applied when
the document is parsed, before #VectorTiles creates its grids, so that the grids are made at the final zoom;
the text of the map (Leaflet controls, attribution, legends, DivIcon labels) is measured and hidden, so that the
image carries no text; and the left and top edges of the vector tiles are returned.

#write_overlay follows the overlays of the book (figs/chap5/depth_under_vessel_overlay.tex,
figs/chap8/map1new_overlay.tex): the image is node `img` of a tikzpicture, labels are placed in the scope
x={(img.south east)}, y={(img.north west)}, and legends are set in font \\captionstyle.
"""
import os
import json
import pathlib

CHROME = os.environ.get('CHROME')  # None: the Chromium that Playwright installs

_INIT = """
document.addEventListener('DOMContentLoaded', () => {
  const ext = %s;
  for (const k in window) {
    const v = window[k];
    if (!(k.startsWith('map_') && v && v.setView)) continue;
    const apply = () => {
      if (ext.view) {  // a fractional zoom, as fitBounds below may give, is kept
        v.options.zoomSnap = 0;
        v.setView([ext.view[0], ext.view[1]], ext.view[2], {animate: false});
      }
      if (ext.bounds) {
        const [s, w, n, e] = ext.bounds;
        v.options.zoomSnap = 0;
        v.fitBounds([[s, w], [n, e]], {padding: [0, 0], animate: false});
      }
    };
    // an animated fitBounds of the page ends its zoom transition at its own zoom: apply after it
    if (v._animatingZoom) v.once('zoomend', apply); else apply();
  }
});"""

_MEASURE = """ext => {
  const map = Object.keys(window).filter(k => k.startsWith('map_') && window[k] && window[k].setView)
                    .map(k => window[k])[0];
  const box = map.getContainer().getBoundingClientRect();
  const labels = [];
  for (const el of document.querySelectorAll('.leaflet-marker-icon')) {
    const t = el.innerText.trim();
    if (!t) continue;
    const inner = el.querySelector('div') || el;
    const r = document.createRange(); r.selectNodeContents(inner);
    const b = r.getBoundingClientRect(), cs = getComputedStyle(inner);
    labels.push({text: t, x0: (b.left - box.left) / box.width, y0: (b.top - box.top) / box.height,
                 x1: (b.right - box.left) / box.width, y1: (b.bottom - box.top) / box.height,
                 color: cs.color, bold: parseInt(cs.fontWeight) >= 600 || !!inner.querySelector('b, strong')});
  }
  const xs = new Set(), ys = new Set();
  const tiles = document.querySelectorAll('svg.leaflet-tile');
  for (const t of tiles) {
    const b = t.getBoundingClientRect();
    xs.add(Math.round((b.left - box.left) * 100) / 100); ys.add(Math.round((b.top - box.top) * 100) / 100);
  }
  for (const [name, lat, lon, anchor] of ext.places || []) {
    const q = map.latLngToContainerPoint([lat, lon]);
    labels.push({text: name, x0: q.x / box.width, y0: q.y / box.height, color: 'rgb(0, 0, 0)', bold: false,
                 place: anchor});
  }
  const c = map.getCenter();
  const fit = ext.bounds ? map.getBoundsZoom([[ext.bounds[0], ext.bounds[1]], [ext.bounds[2], ext.bounds[3]]])
                         : null;
  const ok = ext.view ? Math.abs(map.getZoom() - ext.view[2]) < 1e-9 && Math.abs(c.lat - ext.view[0]) < 1e-6
                        && Math.abs(c.lng - ext.view[1]) < 1e-6
           : ext.bounds ? map.options.zoomSnap === 0 && Math.abs(map.getZoom() - fit) < 1e-6 : true;
  return {labels, zoom: map.getZoom(), extent_applied: ok, tiles: tiles.length, width: box.width, height: box.height,
          rasters: document.querySelectorAll('img.leaflet-tile, canvas').length,
          tile_x: [...xs].sort((a, b) => a - b), tile_y: [...ys].sort((a, b) => a - b)};
}"""


def print_map(html, pdf, css_w, css_h, page_w_in=None, page_h_in=None, view=None, bounds=None,
              hide=(), places=(), delay_ms=6000):
    """Print html to a one-page pdf of page_w_in x page_h_in inches (default: the CSS size at 96 px per
    inch), laid out at css_w x css_h CSS px; view (lat, lon, zoom) or bounds (south, west, north, east)
    give the extent; places (name, lat, lon, TikZ anchor) are returned as labels at their map positions,
    drawn by #write_overlay as a dot and a name. Returns the measured labels, zoom and tile edges (CSS px), also written to
    <pdf>.json."""
    from playwright.sync_api import sync_playwright
    page_w_in = page_w_in or css_w / 96
    page_h_in = page_h_in or css_h / 96
    ext = {'view': list(view) if view else None, 'bounds': list(bounds) if bounds else None,
           'places': [list(pl) for pl in places]}
    # The extent is applied when the document is parsed; a run in which the map ends at another extent
    # (seen under load) is printed again
    for attempt in range(4):
        with sync_playwright() as p:
            b = p.chromium.launch(executable_path=CHROME)
            pg = b.new_page(viewport={'width': css_w, 'height': css_h}, device_scale_factor=2)
            errors = []
            pg.on('pageerror', lambda e: errors.append(str(e)))
            pg.add_init_script(_INIT % json.dumps(ext))
            pg.goto(pathlib.Path(html).resolve().as_uri(), timeout=180000)
            pg.wait_for_load_state('networkidle', timeout=180000)
            pg.wait_for_timeout(delay_ms)
            pg.wait_for_load_state('networkidle', timeout=180000)
            pg.wait_for_timeout(1000)
            info = pg.evaluate(_MEASURE, ext)
            if info['extent_applied']:
                pg.add_style_tag(content=', '.join(('.leaflet-control-container', '.maplegend',
                                 '.leaflet-marker-icon') + tuple(hide)) + ' { display: none !important; }')
                pg.wait_for_timeout(300)
                pg.emulate_media(media='screen')
                pg.pdf(path=pdf, width=f'{page_w_in}in', height=f'{page_h_in}in', print_background=True,
                       scale=page_w_in * 96 / css_w,
                       margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'}, page_ranges='1')
            b.close()
        if info['extent_applied']:
            break
        print(f'{html}: extent not applied (zoom {info["zoom"]}), printing again')
    else:
        raise RuntimeError(f'{html}: extent not applied')
    if errors:
        raise RuntimeError(f'{html}: {errors}')
    if info['tiles'] == 0 or info['rasters']:
        raise RuntimeError(f'{html}: {info["tiles"]} vector tiles, {info["rasters"]} raster elements')
    info.update(css_w=css_w, css_h=css_h, page_w_in=page_w_in, page_h_in=page_h_in)
    pathlib.Path(pdf + '.json').write_text(json.dumps(info, indent=1))
    return info


def categorical_legend(html):
    """(title, [(label, colour)]) of the categorical legend of geopandas `explore` in a saved map."""
    import re
    s = pathlib.Path(html).read_text()
    m = re.search(r"<div class='legend-title'>(.*?)</div>(.*?)</ul>", s, re.S)
    if not m:
        return None
    return m.group(1), re.findall(r"<li><span style='background:(#[0-9a-fA-F]{6})[^']*'></span>(.*?)</li>",
                                  m.group(2))


def colorbar_of(m):
    """The branca colormap of a geopandas `explore` map with a numeric column, or None."""
    import branca.colormap as bcm
    for ch in m._children.values():
        if isinstance(ch, bcm.ColorMap):
            return ch
    return None


def _hex(c):
    """Hex of a CSS rgb()/rgba() colour or a hex string."""
    if c.startswith('#'):
        return c[1:7].upper()
    v = [int(float(x)) for x in c[c.index('(') + 1:c.index(')')].split(',')[:3]]
    return ''.join(f'{x:02X}' for x in v)


def _nice_ticks(lo, hi, n=5):
    import math
    span = hi - lo
    step = 10 ** math.floor(math.log10(span / n))
    for f in (1, 2, 2.5, 5, 10):
        if span / (f * step) <= n:
            step *= f
            break
    t = math.ceil(lo / step) * step
    out = []
    while t <= hi + 1e-9:
        out.append(round(t, 10))
        t += step
    return out


def _tex(s):
    return s.replace('&', r'\&').replace('_', r'\_').replace('%', r'\%').replace('#', r'\#')


def write_overlay(path, graphic, incl, pfx, labels=(), legend=None, colorbar=None, legend_at='south east',
                  comment='', font=r'\captionstyle'):
    """Write the tikzpicture of `graphic` with \\includegraphics[incl], its labels (dicts of #print_map),
    its categorical legend (title, [(label, colour, 'line'|'dot'|'box')]) and its colour bar
    (title, LinearColormap or StepColormap, height cm), vertical, beside the map to the east and
    bottom-aligned with it, one box per class of a StepColormap; a newline in the title breaks its line.
    Colour names are prefixed with pfx. Its text is set in `font`, the caption's by default."""
    out = [f'% Written by vgprint.py ({comment})' if comment else '% Written by vgprint.py.']
    body = []
    cols = {}

    def col(h):
        h = _hex(h)
        if h not in cols:
            cols[h] = f'{pfx}c{len(cols)}'
        return cols[h]

    body.append(r'\begin{tikzpicture}')
    body.append(rf'\node[anchor=south west, inner sep=0] (img) {{\includegraphics[{incl}]{{{graphic}}}}};')
    if labels:
        body.append(rf'\begin{{scope}}[x={{(img.south east)}}, y={{(img.north west)}}, font={font}]')
        for lb in labels:
            t = _tex(lb['text'])
            if lb.get('bold'):
                t = rf'\textbf{{{t}}}'
            if lb.get('place'):
                name = rf' node[anchor={lb["place"]}, inner sep=1.5pt] {{{t}}}' if t else ''
                body.append(rf'\fill ({lb["x0"]:.4f}, {1 - lb["y0"]:.4f}) circle (0.8pt){name};')
                continue
            body.append(rf'\node[anchor=north west, inner sep=0.5pt, text={col(lb["color"])}] at '
                        rf'({lb["x0"]:.4f}, {1 - lb["y0"]:.4f}) {{{t}}};')
        body.append(r'\end{scope}')
    if legend:
        title, items = legend
        rows = []
        for label, c, kind in items:
            if kind == 'line':
                sw = rf'\tikz[baseline=-0.6ex]\draw[line width=1.2pt, color={col(c)}] (0,0) -- (0.3,0);'
            elif kind == 'dot':
                sw = (rf'\tikz[baseline=-0.6ex]\fill[color={col(c)}, draw=black!60, line width=0.2pt] '
                      r'(0,0) circle (1.6pt);')
            else:
                sw = rf'\tikz[baseline=-0.6ex]\fill[color={col(c)}] (0,-0.08) rectangle (0.16,0.08);'
            rows.append(rf'{sw} & {_tex(label)} \\')
        if legend_at.startswith('outside '):
            # Beside the map, bottom-aligned, so that it hides none of it
            side = legend_at.split()[1]
            anchor, at = (('south west', '[xshift=4pt]img.south east') if side == 'east' else
                          ('south east', '[xshift=-4pt]img.south west'))
            body.append(rf'\node[anchor={anchor}, inner sep=0pt, font={font}] at ({at}) {{%')
        else:
            anchor = legend_at
            xs = '-3pt' if 'east' in anchor else '3pt'
            ys = '3pt' if 'south' in anchor else '-3pt'
            body.append(rf'\node[anchor={anchor}, fill=white, fill opacity=0.85, text opacity=1, '
                        rf'inner sep=2pt, font={font}] at ([xshift={xs}, yshift={ys}]img.{anchor}) {{%')
        body.append(r'\begin{tabular}{@{}c@{\hspace{3pt}}l@{}}')
        body.append(rf'\multicolumn{{2}}{{@{{}}l@{{}}}}{{{_tex(title)}}} \\')
        body.extend(rows)
        body.append(r'\end{tabular}};')
    if colorbar:
        title, cm, hcm = colorbar
        lo, hi = cm.vmin, cm.vmax
        y = lambda v: hcm * (v - lo) / (hi - lo)
        wbar = 0.35
        body.append(rf'\begin{{scope}}[shift={{(img.south east)}}, xshift=0.25cm, font={font}]')
        if hasattr(cm, 'index'):
            # a StepColormap: one box per class, as the map colours it
            for a, b in zip(cm.index[:-1], cm.index[1:]):
                body.append(rf'\fill[color={col(cm.rgb_hex_str((a + b) / 2))}] (0, {y(a):.3f}) '
                            rf'rectangle ({wbar}, {y(b):.3f});')
        else:
            n = 8
            stops = [lo + (hi - lo) * i / n for i in range(n + 1)]
            names = [col(cm.rgb_hex_str(v)) for v in stops]
            for i in range(n):
                body.append(rf'\shade[bottom color={names[i]}, top color={names[i + 1]}] '
                            rf'(0, {y(stops[i]):.3f}) rectangle ({wbar}, {y(stops[i + 1]):.3f});')
        body.append(rf'\draw[line width=0.2pt] (0, 0) rectangle ({wbar}, {hcm:.3f});')
        for t in _nice_ticks(lo, hi):
            body.append(rf'\draw[line width=0.2pt] ({wbar}, {y(t):.3f}) -- ++(0.06, 0) '
                        rf'node[anchor=west, inner sep=1pt] {{{t:,.0f}}};')
        body.append(rf'\node[anchor=south west, inner sep=0, align=left] at (0, {hcm + 0.4:.3f}) '
                    rf'{{{_tex(title).replace(chr(10), r" \\ ")}}};')
        body.append(r'\end{scope}')
    body.append(r'\end{tikzpicture}%')
    # each line outside the tikzpicture ends with %, so that the overlay adds no space where it is \input
    out += [rf'\definecolor{{{n}}}{{HTML}}{{{h}}}%' for h, n in cols.items()]
    pathlib.Path(path).write_text('\n'.join(out + body) + '\n')
