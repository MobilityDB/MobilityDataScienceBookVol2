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
# One CSS px of a map prints as MM_PER_PX mm, so that a weight or a radius of explore() and the roads
# of the basemap print alike in every map: weight 4 is 0.4 mm, radius 7 a 1.4 mm dot
MM_PER_PX = 0.1

_INIT = """
document.addEventListener('DOMContentLoaded', () => {
  const ext = %s;
  for (const k in window) {
    const v = window[k];
    if (!(k.startsWith('map_') && v && v.setView)) continue;
    const apply = () => {
      if (ext.view) v.setView([ext.view[0], ext.view[1]], ext.view[2], {animate: false});
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


_PAD = """import sys, pikepdf
pdf, under, above = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
with pikepdf.open(pdf, allow_overwriting_input=True) as p:
    for page in p.pages:
        x0, y0, x1, y1 = [float(v) for v in page.mediabox]
        page.mediabox = [x0, y0 - under, x1, y1 + above]
        if '/CropBox' in page.obj:
            del page.obj['/CropBox']
    p.save(pdf)
"""


def page_size_in(pdf):
    """The width and the height in inches of the first page of pdf as Chrome printed it, which can
    differ by a fraction of a millimeter from the size #print_map asks for, read by pdfinfo."""
    import re
    import subprocess
    out = subprocess.run(['pdfinfo', pdf], capture_output=True, text=True, check=True).stdout
    w, h = re.search(r'Page size:\s+([\d.]+) x ([\d.]+) pts', out).groups()
    return float(w) / 72, float(h) / 72


def pad_page(pdf, under_in, above_in):
    """Adds white space of under_in and above_in inches under and above the page of the map pdf, so
    that the map is set beside a chart whose box has the height of the map and whose labels lie under
    and above it (#print_panel_box of print_panels.py), with the Python of PIKEPDF_PY when the Python
    of the figure script has no pikepdf, as #simplify_printed of pdf_simplify.py does."""
    import subprocess
    import sys
    py = os.environ.get('PIKEPDF_PY', sys.executable)
    subprocess.run([py, '-c', _PAD, pdf, str(under_in * 72), str(above_in * 72)], check=True)


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
                  colorbar_at='north east', comment='', font=r'\captionstyle'):
    """Write the tikzpicture of `graphic` with \\includegraphics[incl], its labels (dicts of #print_map),
    its categorical legend (title, [(label, colour, 'line'|'dot'|'box')]) and its colour bar
    (title, LinearColormap, width cm); colour names are prefixed with pfx. Its text is set in `font`, the
    caption's by default."""
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
                if not lb.get('dot', True):
                    # A name beside a mark that the map draws itself
                    body.append(rf'\node[anchor={lb["place"]}, inner sep=1pt] at '
                                rf'({lb["x0"]:.4f}, {1 - lb["y0"]:.4f}) {{{t}}};')
                    continue
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
        title, cm, wcm = colorbar
        lo, hi = cm.vmin, cm.vmax
        n = 8
        stops = [lo + (hi - lo) * i / n for i in range(n + 1)]
        names = [col(cm.rgb_hex_str(v)) for v in stops]
        x = lambda v: wcm * (v - lo) / (hi - lo)
        anchor = colorbar_at
        h = 0.95
        x_off = f'-{wcm + 0.25:.2f}cm' if 'east' in anchor else '0.25cm'
        y_off = f'-{h + 0.1:.2f}cm' if 'north' in anchor else '0.1cm'
        body.append(rf'\begin{{scope}}[shift={{(img.{anchor})}}, xshift={x_off}, yshift={y_off}, '
                    rf'font={font}]')
        body.append(rf'\fill[white, opacity=0.85] (-0.15, -0.02) rectangle ({wcm + 0.15:.3f}, {h:.2f});')
        body.append(rf'\node[anchor=south west, inner sep=0] at (0, 0.58) {{{_tex(title)}}};')
        for i in range(n):
            body.append(rf'\shade[left color={names[i]}, right color={names[i + 1]}] ({x(stops[i]):.3f}, 0.40) '
                        rf'rectangle ({x(stops[i + 1]):.3f}, 0.52);')
        body.append(rf'\draw[line width=0.2pt] (0, 0.40) rectangle ({wcm:.3f}, 0.52);')
        for t in _nice_ticks(lo, hi):
            lab = f'{t:g}'
            body.append(rf'\draw[line width=0.2pt] ({x(t):.3f}, 0.40) -- ++(0, -0.04) '
                        rf'node[anchor=north, inner sep=0.5pt] {{{lab}}};')
        body.append(r'\end{scope}')
    body.append(r'\end{tikzpicture}%')
    # each line outside the tikzpicture ends with %, so that the overlay adds no space where it is \input
    out += [rf'\definecolor{{{n}}}{{HTML}}{{{h}}}%' for h, n in cols.items()]
    pathlib.Path(path).write_text('\n'.join(out + body) + '\n')
