"""Vector-tile basemap for Folium maps, as printed in Chapter 7, and a Playwright screenshot.

Folium has no vector-style layer. VectorTiles stands beside folium's raster `#TileLayer`, which it
replaces: the map is created with tiles=None, and Leaflet.VectorGrid draws the OpenMapTiles vector
tiles of OpenFreeMap with Leaflet's SVG renderer, so that a printed PDF keeps the basemap as vector
paths; the styles come from #style_layers of omtstyle.py. JSCSSMixin places the VectorGrid script after Leaflet in the page header.
"""
import os

from branca.element import MacroElement
from folium.elements import JSCSSMixin
from jinja2 import Template

CHROME = os.environ.get('CHROME')  # None: the Chromium that Playwright installs

# --- the helper printed in the chapter ---------------------------------------------------
from omtstyle import style_layers  # OpenFreeMap colours, without labels

class VectorTiles(JSCSSMixin, MacroElement):
    default_js = [("vectorgrid", "https://unpkg.com/leaflet.vectorgrid@1.3.0"
                   "/dist/Leaflet.VectorGrid.bundled.min.js")]
    _template = Template("""
      {% macro header(this, kwargs) %}
        <style>svg.leaflet-tile { overflow: visible; clip-path: inset(-1px); }</style>
      {% endmacro %}
      {% macro script(this, kwargs) %}
      fetch("https://tiles.openfreemap.org/planet").then(r => r.json()).then(tj => {
        const map = {{ this._parent.get_name() }};
        map.getContainer().style.background = "{{ this.bg }}";
        for (const styles of {{ this.layers }}(map))  // areas, casings, road fills
          L.vectorGrid.protobuf(tj.tiles[0], {rendererFactory: L.svg.tile,
            maxNativeZoom: 14, interactive: false, vectorTileLayerStyles: styles})
           .addTo(map);
      });{% endmacro %}""")

    def __init__(self, style="positron"):
        super().__init__()
        self.bg, self.layers = style_layers(style)
# ------------------------------------------------------------------------------------------


def screenshot(html, png, width, height, delay_ms=5000, scale=2, pdf='auto', dsf=4):
    """Render html headless and save png of width x height device pixels.

    Chromium is launched with ANGLE over SwiftShader for WebGL. The page is laid out at
    (width/scale) x (height/scale) CSS pixels with the given device scale factor. The zoom buttons
    are hidden; the attribution stays.
    """
    from playwright.sync_api import sync_playwright
    import pathlib
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=CHROME, args=[
            '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        if pdf == 'auto':
            pdf = png[:-4] + '.pdf'
        # layout at (width/scale) x (height/scale) CSS px; the WebGL basemap is rasterized at dsf device pixels per CSS px, and the
        # Leaflet SVG layers of the data stay vector paths in the printed PDF
        pg = b.new_page(viewport={'width': round(width / scale), 'height': round(height / scale)},
                        device_scale_factor=dsf)
        errors = []
        pg.on('pageerror', lambda e: errors.append(str(e)))
        pg.goto(pathlib.Path(html).resolve().as_uri())
        pg.add_style_tag(content='.leaflet-control-zoom {display: none !important;} '
                         '.leaflet-control-attribution {font-size: 8px !important;}')
        pg.wait_for_load_state('networkidle')
        pg.wait_for_timeout(delay_ms)
        pg.wait_for_load_state('networkidle')
        pg.screenshot(path=png)
        if pdf:
            pg.emulate_media(media='screen')
            pg.pdf(path=pdf, width=f'{round(width / scale)}px',
                   height=f'{round(height / scale)}px', print_background=True,
                   margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'},
                   page_ranges='1')
        b.close()
        if errors:
            raise RuntimeError(f'{html}: {errors}')
