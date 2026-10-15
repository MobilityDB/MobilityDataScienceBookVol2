"""Print a chapter 9 dashboard to a PDF with Playwright Chromium once a condition holds in the page.

The page is opened in Chromium with SwiftShader for WebGL, and printed once a JavaScript
condition holds (the window that the figure shows) and the basemap has settled. The PDF has the
printed width of the figure and the aspect of the viewport. Leaflet draws the data with its SVG
renderer, which prints as vectors, and MapLibre GL the OpenStreetMap vector-tile basemap on a WebGL
canvas, which prints as one image; the device scale factor makes that canvas 300 dpi of the
printed size. A PNG preview is written beside it.

    python capture.py <url> <out.pdf> <width> <height> <js-condition> [settle_s] [timeout_s] [width_mm]
"""
import sys
import time

from playwright.sync_api import sync_playwright

url, out, width, height, cond = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
settle = float(sys.argv[6]) if len(sys.argv) > 6 else 20
timeout = float(sys.argv[7]) if len(sys.argv) > 7 else 900
width_mm = float(sys.argv[8]) if len(sys.argv) > 8 else 332.89723 / 72.27 * 25.4   # \textwidth of svmono

# The zoom buttons and the attribution are hidden; the caption credits the basemap.
HIDE = ".leaflet-control-zoom, .leaflet-control-attribution { display: none !important; }"

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
