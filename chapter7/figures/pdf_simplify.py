"""Simplification of the paths of a map PDF printed by Chromium (#print_map of vgprint.py) below the
resolution at which the book prints it.

A map of the book is printed small: the vector tiles of a city at zoom 12, printed 6 cm high, carry
many vertices closer together than a pixel of the printed page, and every one of them costs a viewer
time to draw. #simplify_pdf replaces each run of line segments ("x y l") of every content stream of
the page, form XObjects included, by its Douglas-Peucker simplification with a tolerance of `tol`
points of the PDF page, converted into the units of each stream by the scale of its transformation
matrix, so that no vertex moves farther than `tol` on the page. #print_tol gives the tolerance of
half a pixel of the page as the book prints it at 300 dpi. The content is read line by line, one
operator per line, as Chromium writes it and as #squeeze of vghybrid.py reads it; curves, rectangles,
clip paths and every other operator are kept as they are. #simplify_printed rewrites a map in place
with the Python of PIKEPDF_PY when the Python of the figure script has no pikepdf, as
#print_map_hybrid of vghybrid.py composites its image.
"""
import os
import subprocess
import sys

PIKEPDF_PY = os.environ.get('PIKEPDF_PY', sys.executable)


def print_tol(page_w_pt, printed_w_mm, fraction=0.5):
    """`fraction` of a 300-dpi pixel of the page printed `printed_w_mm` wide, in points of the page
    `page_w_pt` points wide."""
    return fraction * 72 / 300 * page_w_pt / (printed_w_mm * 72 / 25.4)


def _simplify_stream(stream, scale, tol, forms, counts, stack):
    """Rewrite the content of `stream`, drawn at `scale` page points per unit, with `stack` the scales
    saved by the q operators of the streams before it on the page; record in `forms` the scale at which
    each form XObject is drawn, and return the scale at the end of the stream."""
    from shapely.geometry import LineString
    out, run = [], []
    start = None

    def flush():
        if len(run) > 1:
            pts = list(LineString([start] + run).simplify(tol / scale, preserve_topology=False).coords)[1:]
            if not pts:
                pts = run[-1:]
        else:
            pts = run[:]
        counts[0] += len(run)
        counts[1] += len(pts)
        out.extend(f'{x:.4f} {y:.4f} l'.encode() for x, y in pts)
        run.clear()

    for ln in stream.read_bytes().split(b'\n'):
        t = ln.split()
        if len(t) == 3 and t[2] == b'l':
            run.append((float(t[0]), float(t[1])))
            continue
        if run:
            flush()
        out.append(ln)
        # The operators of the line in order, each with its operands: Chromium writes one per line,
        # the composite of vghybrid.py several
        args = []
        for tok in t:
            if tok[:1] in b'/0123456789.-+' or tok in (b'[', b']'):
                args.append(tok)
                continue
            if tok == b'm' and len(args) >= 2:
                start = (float(args[-2]), float(args[-1]))
            elif tok == b'q':
                stack.append(scale)
            elif tok == b'Q':
                scale = stack.pop()
            elif tok == b'cm' and len(args) >= 6:
                a, b, c, d = (float(v) for v in args[-6:-2])
                scale *= max(abs(a * d - b * c), 1e-12) ** 0.5
            elif tok == b'Do' and args:
                forms.setdefault(args[-1].decode(), scale)
            args = []
    if run:
        flush()
    stream.write(b'\n'.join(out))
    return scale


def simplify_pdf(pdf_in, pdf_out, tol):
    """Simplify every run of line segments of the first page of pdf_in and of the forms it draws, with
    a tolerance of tol points of the page; write pdf_out, which may be pdf_in."""
    import pikepdf
    pdf = pikepdf.open(pdf_in, allow_overwriting_input=True)
    page = pdf.pages[0]
    counts = [0, 0]
    todo = [(page.obj, 1.0, True)]
    done = set()
    while todo:
        obj, scale, is_page = todo.pop()
        res = obj.get('/Resources')
        if not is_page:
            streams = [obj]
        elif isinstance(obj.Contents, pikepdf.Array):
            streams = list(obj.Contents)
        else:
            streams = [obj.Contents]
        forms, stack = {}, []
        for s in streams:
            scale = _simplify_stream(s, scale, tol, forms, counts, stack)
        xo = res.get('/XObject') if res is not None else None
        for name, sc in forms.items():
            x = xo.get(name) if xo is not None else None
            if x is not None and x.get('/Subtype') == '/Form' and x.objgen not in done:
                done.add(x.objgen)
                m = x.get('/Matrix')
                if m is not None:
                    a, b, c, d = (float(v) for v in list(m)[:4])
                    sc *= max(abs(a * d - b * c), 1e-12) ** 0.5
                todo.append((x, sc, False))
    pdf.save(pdf_out, compress_streams=True, object_stream_mode=pikepdf.ObjectStreamMode.generate)
    print(f'{pdf_in}: {counts[0]} line vertices -> {counts[1]} at {tol:.4f} pt')
    return counts


def simplify_printed(pdf, printed_w_mm, fraction=0.5):
    """Simplify the map pdf in place at `fraction` of a pixel of the page as the book prints it
    `printed_w_mm` wide at 300 dpi."""
    try:
        import pikepdf
        import shapely  # noqa: F401
    except ImportError:  # this Python has no pikepdf: simplify with the Python of PIKEPDF_PY
        subprocess.run([PIKEPDF_PY, os.path.abspath(__file__), pdf, pdf, str(printed_w_mm), str(fraction)],
                       check=True)
        return
    with pikepdf.open(pdf) as p:
        box = [float(v) for v in p.pages[0].mediabox]
    simplify_pdf(pdf, pdf, print_tol(box[2] - box[0], printed_w_mm, fraction))


if __name__ == '__main__':
    # pdf_simplify.py <in.pdf> <out.pdf> <printed width in mm> [fraction of a printed pixel, 0.5]
    import pikepdf
    with pikepdf.open(sys.argv[1]) as p:
        box = [float(v) for v in p.pages[0].mediabox]
    frac = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    simplify_pdf(sys.argv[1], sys.argv[2], print_tol(box[2] - box[0], float(sys.argv[3]), frac))
