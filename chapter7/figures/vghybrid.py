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

"""Printing of a Folium map whose basemap is #VectorTiles (Leaflet.VectorGrid, SVG) and whose data layer is
too dense to stay vector: the basemap is printed as vector paths and the data layer is embedded as one
lossless image.

#print_map_hybrid follows #print_map of vgprint.py (headless Chrome, extent applied when the document is
parsed, text measured and hidden, the same _INIT and _MEASURE scripts), and prints the page twice from one
layout:
  * the page is printed to PDF with the data pane hidden (by default `.leaflet-overlay-pane`, where Folium
    draws its circle markers and vector layers), so that the basemap stays vector;
  * the page is printed again with the basemap hidden and no page or map background, so that the data
    pane alone is drawn as vector paths on a transparent page, which pdftocairo -transp rasterizes at
    `dpi` pixels per inch of the PDF page (the image has the geometry of the vector print of #print_map);
  * the image is placed over the whole page of the basemap PDF as an RGB image with a soft mask, both Flate
    encoded with the PNG predictors (the IDAT streams of the PNG files, as img2pdf embeds a PNG): lossless,
    full colour, not palette-quantized, never JPEG.
The layout is the one of #print_map: the viewport is the map, and the PDF page is the viewport scaled to
page_w_in x page_h_in inches; both prints have that page, and the image spans it.
"""
import os
import sys
import io
import json
import pathlib
import struct
import zlib

from vgprint import CHROME, _INIT, _MEASURE
from pdf_simplify import squeeze

TEXTWIDTH_MM = 117  # \textwidth of svmono, the class of the book


def print_dpi(css_w, width):
    """The dpi of #print_map_hybrid at which the data image has the pixels of the map as the book prints it
    at 300 dpi, so that no viewer resamples it: width is the fraction of \\textwidth of the
    \\includegraphics of the map, css_w the CSS width of the page."""
    return 300 * width * TEXTWIDTH_MM / 25.4 / (css_w / 96)

PIKEPDF_PY = os.environ.get('PIKEPDF_PY', sys.executable)


def _idat(img):
    """The concatenated IDAT data of img saved as a non-interlaced PNG (zlib stream of PNG-filtered rows)."""
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True, compress_level=9)
    b = buf.getvalue()
    pos, out = 8, []
    while pos < len(b):
        n, typ = struct.unpack('>I4s', b[pos:pos + 8])
        if typ == b'IHDR':
            assert b[pos + 8 + 12] == 0, 'interlaced PNG'
            assert b[pos + 8 + 8] == 8, 'not 8 bits per component'
        if typ == b'IDAT':
            out.append(b[pos + 8:pos + 8 + n])
        pos += 12 + n
    data = b''.join(out)
    zlib.decompress(data)  # a complete zlib stream
    return data


def _bleed(im, passes=4):
    """The RGB channels of the RGBA image im in which each transparent pixel near the data takes the colour
    of its data neighbours: the four-neighbour mean over four passes. A viewer that interpolates the colour and the soft mask separately would otherwise mix the black
    of a transparent pixel into the edge of every marker."""
    import numpy as np
    from PIL import Image
    a = np.asarray(im).copy()
    known = a[..., 3] > 0
    for _ in range(passes):
        if known.all():
            break
        acc = np.zeros(a.shape[:2] + (3,), float); cnt = np.zeros(a.shape[:2], float)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            k = np.roll(known, (dy, dx), (0, 1)); v = np.roll(a[..., :3], (dy, dx), (0, 1))
            acc += v * k[..., None]; cnt += k
        grow = ~known & (cnt > 0)
        a[grow, :3] = (acc[grow] / cnt[grow, None]).round().astype(np.uint8)
        known = known | grow
    return Image.fromarray(a[..., :3].copy(), 'RGB')


def composite(pdf_in, png, pdf_out):
    """Place the RGBA image png over the whole first page of pdf_in, writing pdf_out; the page's own
    content is first rewritten by #squeeze."""
    import pikepdf
    from PIL import Image
    im = Image.open(png)
    assert im.mode == 'RGBA', im.mode
    w, h = im.size
    rgb, alpha = _bleed(im), im.getchannel('A')
    pdf = pikepdf.open(pdf_in)
    smask = pikepdf.Stream(pdf, _idat(alpha))
    smask.stream_dict = pikepdf.Dictionary(
        Type=pikepdf.Name.XObject, Subtype=pikepdf.Name.Image, Width=w, Height=h,
        ColorSpace=pikepdf.Name.DeviceGray, BitsPerComponent=8, Filter=pikepdf.Name.FlateDecode,
        DecodeParms=pikepdf.Dictionary(Predictor=15, Colors=1, BitsPerComponent=8, Columns=w))
    img = pikepdf.Stream(pdf, _idat(rgb))
    img.stream_dict = pikepdf.Dictionary(
        Type=pikepdf.Name.XObject, Subtype=pikepdf.Name.Image, Width=w, Height=h,
        ColorSpace=pikepdf.Name.DeviceRGB, BitsPerComponent=8, Filter=pikepdf.Name.FlateDecode,
        DecodeParms=pikepdf.Dictionary(Predictor=15, Colors=3, BitsPerComponent=8, Columns=w),
        SMask=smask, Interpolate=False)
    page = pdf.pages[0]
    x0, y0, x1, y1 = [float(v) for v in page.mediabox]
    gs = {str(k): {str(a): str(b) for a, b in v.items()}
          for k, v in page.obj.Resources.get('/ExtGState', {}).items()}
    old = page.obj.Contents
    assert isinstance(old, pikepdf.Stream), 'one content stream expected'
    data = old.read_bytes()
    new, merged = squeeze(data, gs, (x0, y0, x1, y1))
    old.write(new)
    print(f'{pdf_in}: content {len(data)} -> {len(new)} bytes, {merged} fill+stroke pairs merged')
    if '/Resources' not in page.obj:
        page.obj.Resources = pikepdf.Dictionary()
    res = page.obj.Resources
    if '/XObject' not in res:
        res.XObject = pikepdf.Dictionary()
    name = '/DataLayer'
    assert name not in res.XObject
    res.XObject[name] = img
    # the page's own content is enclosed in q ... Q, so that the image is drawn in the page's default space
    page.contents_add(pikepdf.Stream(pdf, b'q\n'), prepend=True)
    page.contents_add(pikepdf.Stream(pdf, (f'Q\nq {x1 - x0:.4f} 0 0 {y1 - y0:.4f} {x0:.4f} {y0:.4f} cm '
                                           f'{name} Do Q\n').encode()))
    pdf.save(pdf_out, compress_streams=True, object_stream_mode=pikepdf.ObjectStreamMode.generate)


def print_map_hybrid(html, pdf, css_w, css_h, page_w_in=None, page_h_in=None, view=None, bounds=None,
                     hide=(), places=(), delay_ms=6000, dpi=300, data_sel='.leaflet-overlay-pane'):
    """As #print_map of vgprint.py, with the panes matched by data_sel embedded as one lossless image of
    dpi pixels per inch of the PDF page over the vector basemap. The basemap alone is printed to
    <pdf>.base.pdf, the data layer alone (vector, transparent page) to <pdf>.data.pdf, which pdftocairo
    rasterizes with its transparency to <pdf>.data.png."""
    import subprocess
    from playwright.sync_api import sync_playwright
    page_w_in = page_w_in or css_w / 96
    page_h_in = page_h_in or css_h / 96
    ext = {'view': list(view) if view else None, 'bounds': list(bounds) if bounds else None,
           'places': [list(pl) for pl in places]}
    base_pdf, data_pdf, png = pdf + '.base.pdf', pdf + '.data.pdf', pdf + '.data.png'
    hidden = ', '.join(('.leaflet-control-container', '.maplegend', '.leaflet-marker-icon') + tuple(hide))

    def to_pdf(pg, path):
        pg.wait_for_timeout(300)
        pg.pdf(path=path, width=f'{page_w_in}in', height=f'{page_h_in}in', print_background=True,
               scale=page_w_in * 96 / css_w,
               margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'}, page_ranges='1')

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
                pg.add_style_tag(content=hidden + ' { display: none !important; }')
                pg.emulate_media(media='screen')
                # the basemap alone, printed as vector paths
                pg.add_style_tag(content=data_sel + ' { visibility: hidden !important; }')
                to_pdf(pg, base_pdf)
                # the data layer alone, on a transparent page (no page colour, no map background)
                pg.add_style_tag(content=data_sel + ' { visibility: visible !important; } '
                                 '.leaflet-tile-pane { visibility: hidden !important; } '
                                 'html, body { background: transparent !important; }')
                pg.evaluate("""() => { for (const k in window) { const v = window[k];
                    if (k.startsWith('map_') && v && v.setView)
                      v.getContainer().style.setProperty('background', 'transparent', 'important'); } }""")
                pg.context.new_cdp_session(pg).send('Emulation.setDefaultBackgroundColorOverride',
                                                    {'color': {'r': 0, 'g': 0, 'b': 0, 'a': 0}})
                to_pdf(pg, data_pdf)
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
    subprocess.run(['pdftocairo', '-png', '-transp', '-r', str(dpi), '-singlefile', data_pdf, png[:-4]],
                   check=True)
    from PIL import Image
    im = Image.open(png)
    if im.mode != 'RGBA' or im.getchannel('A').getextrema()[0] != 0:
        raise RuntimeError(f'{png}: {im.mode}: the data page is not transparent')
    try:
        import pikepdf  # noqa: F401
        composite(base_pdf, png, pdf)
    except ImportError:  # this Python has no pikepdf: composite with the Python of PIKEPDF_PY
        subprocess.run([PIKEPDF_PY, __file__, base_pdf, png, pdf], check=True)
    info.update(css_w=css_w, css_h=css_h, page_w_in=page_w_in, page_h_in=page_h_in, dpi=dpi, data_px=im.size)
    pathlib.Path(pdf + '.json').write_text(json.dumps(info, indent=1))
    return info


if __name__ == '__main__':
    # vghybrid.py <basemap.pdf> <data.png> <out.pdf>: the composite step alone
    import sys
    composite(*sys.argv[1:4])
