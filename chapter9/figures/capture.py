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

"""Print a dashboard of chapters 8 and 9 to a PDF with Playwright Chromium once a condition holds.

The page is opened in Chromium with SwiftShader for WebGL, and printed once a JavaScript
condition holds (the window that the figure shows) and the basemap has settled. The PDF has the
printed width of the figure and the aspect of the viewport. The text, the metrics and the charts
of the page print as vectors; a map, drawn on a WebGL canvas by MapLibre GL (the OpenStreetMap
vector-tile basemap) and deck.gl (the pydeck layers of the Streamlit dashboards), prints as one
image, and the device scale factor makes that canvas 300 dpi of the printed size. A Leaflet page
draws its data with the SVG renderer, which prints as vectors. A PNG preview is written beside it.

    python capture.py <url> <out.pdf> <width> <height> <js-condition> [settle_s] [timeout_s] [width_mm]
"""
import sys
import time

from playwright.sync_api import sync_playwright

url, out, width, height, cond = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
settle = float(sys.argv[6]) if len(sys.argv) > 6 else 20
timeout = float(sys.argv[7]) if len(sys.argv) > 7 else 900
width_mm = float(sys.argv[8]) if len(sys.argv) > 8 else 332.89723 / 72.27 * 25.4   # \textwidth of svmono

# The zoom buttons and the attribution of Leaflet are hidden; the caption credits the basemap.
# The page of a Streamlit app fills the figure, without the margins around its content and
# without its header, which would otherwise lie over the title of the page.
HIDE = (".leaflet-control-zoom, .leaflet-control-attribution { display: none !important; }"
        " [data-testid='stMainBlockContainer'] { padding: 8px 8px !important; }"
        " [data-testid='stHeader'] { display: none !important; }")

# A WebGL canvas prints blank unless its drawing buffer is kept after each frame.
KEEP_BUFFER = """
const getContext = HTMLCanvasElement.prototype.getContext;
HTMLCanvasElement.prototype.getContext = function (type, attrs) {
  if (type === 'webgl' || type === 'webgl2') attrs = Object.assign({}, attrs, {preserveDrawingBuffer: true});
  return getContext.call(this, type, attrs);
};
"""
scale = width_mm / 25.4 * 96 / width              # CSS pixels of the viewport onto the printed width
dsf = max(1.0, 300 / 96 * scale)                  # canvas pixels per CSS pixel for 300 dpi on paper

with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader",
                                "--enable-unsafe-swiftshader"])
    pg = b.new_page(viewport={"width": width, "height": height}, device_scale_factor=dsf)
    pg.add_init_script(KEEP_BUFFER)
    msgs = []
    pg.on("console", lambda m: msgs.append(f"{m.type}: {m.text}"[:300]))
    t = time.time()
    pg.goto(url, timeout=120000)
    try:
        pg.wait_for_function(cond, timeout=timeout * 1000, polling=500)
    except Exception:
        pg.screenshot(path=out[:-4] + "_timeout.png")
        print("condition never held; page text:", pg.inner_text("body")[:600])
        raise
    pg.add_style_tag(content=HIDE)
    pg.wait_for_timeout(settle * 1000)
    pg.screenshot(path=out[:-4] + ".png", full_page=False)
    pg.emulate_media(media="screen")
    pg.pdf(path=out, width=f"{width_mm:.3f}mm", height=f"{width_mm * height / width:.3f}mm",
           scale=scale, print_background=True, margin={"top": "0", "right": "0", "bottom": "0", "left": "0"},
           page_ranges="1")
    print("printed", out, "after %.0f s, scale %.4f, device scale %.3f" % (time.time() - t, scale, dsf))
    for m in msgs[-10:]:
        print(m)
    b.close()
