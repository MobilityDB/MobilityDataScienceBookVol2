"""Figures pymeosbmod10 (printed Series) and pymeosbmod12_a/b (DataFrame tables) of chapter 2:
the notebook outputs of the listings, rendered from the values written by bmod_listings.py as
HTML and printed by headless Chromium to vector PDFs (text, no images). The PDFs have the size at
which the book prints them, unscaled, and their text the size whose x-height is that of the
captions, as the titles of Fig. 7.17 (chapter7/figures/fig_hanoi.py): DejaVu Sans, x-height
0.547 em, against LM Roman 9 of the captions, 0.431 em at 8.5 TeX points, gives 6.67 points."""
import html
import os
from pathlib import Path
import pandas as pd
from playwright.sync_api import sync_playwright

OUT = Path(__file__).resolve().parent / 'out'
CHROME = os.environ.get('CHROME')  # None: the Chromium that Playwright installs
FS = f'{8.5 * 72 / 72.27 * 0.431 / 0.547:.3f}pt'  # 6.67 pt
CSS = f"""body {{ margin: 0; font-family: 'DejaVu Sans', sans-serif; font-size: {FS}; background: #fff; }}
pre {{ font-family: 'DejaVu Sans Mono', monospace; font-size: {FS}; margin: 2px 3px; }}
table {{ border-collapse: collapse; margin: 2px; font-size: {FS}; }}
th, td {{ padding: 2px 4px; text-align: right; white-space: nowrap; }}
thead th {{ border-bottom: 1px solid #000; }}
tbody tr:nth-child(odd) {{ background: #f5f5f5; }}
tbody th {{ font-weight: bold; }}"""


def trunc(s, n):
    return s if len(s) <= n else s[:n] + '...'


def render(body, name):
    page_html = f'<html><head><meta charset="utf-8"><style>{CSS}</style></head><body>' \
                f'<div id="c" style="display:inline-block">{body}</div></body></html>'
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=CHROME)
        pg = b.new_page()
        pg.set_content(page_html)
        box = pg.locator('#c').bounding_box()
        w, h = int(box['width']) + 2, int(box['height']) + 2
        pg.pdf(path=f'{OUT}/{name}.pdf', width=f'{w}px', height=f'{h}px', print_background=True,
               margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'}, page_ranges='1')
        pg.set_viewport_size({'width': w, 'height': h})
        pg.screenshot(path=f'{OUT}/{name}.png')
        b.close()


render(f'<pre>{html.escape(open(f"{OUT}/pymeosbmod10.txt").read())}</pre>', 'pymeosbmod10')

sp = pd.read_csv(f'{OUT}/spatial_aggregates.csv').head(6)
sp['tile'] = sp['tile'].map(lambda s: trunc(s, 34))
sp['duration'] = pd.to_timedelta(sp['duration']).astype(str)
sp['distance'] = sp['distance'].map(lambda v: f'{v:.6f}')
render(sp.to_html(), 'pymeosbmod12_a')

va = pd.read_csv(f'{OUT}/speed_aggregates.csv').head(6)
va['tile'] = va['tile'].map(lambda s: trunc(s, 34))
va['duration'] = pd.to_timedelta(va['duration']).astype(str)
render(va.to_html(), 'pymeosbmod12_b')
