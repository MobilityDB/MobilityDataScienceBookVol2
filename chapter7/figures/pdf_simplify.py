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
clip paths and every other operator are kept as they are. With `squeezed`, the content of the page is
then rewritten by #squeeze, which leaves out the subpaths outside the clip and paints each area that
Chromium fills and then strokes in one operator, as #composite of vghybrid.py does: a map whose basemap
draws areas (residential, parks, water) draws faster. #simplify_printed rewrites a map in place with the
Python of PIKEPDF_PY when the Python of the figure script has no pikepdf, as #print_map_hybrid of
vghybrid.py composites its image.
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


_PATH_OPS = {b'm', b'l', b'c', b'v', b'y', b'h', b're'}
_PAINT_OPS = {b'f', b'F', b'f*', b'S', b's', b'B', b'B*', b'b', b'b*'}


def squeeze(content, gstates, page_box, margin=4.0):
    """The content stream of a Skia page with the same rendering and fewer path operators:
      * a subpath whose bounding box, grown by `margin` user units (more than half the widest line, the
        joins being round), lies outside the clip rectangle in force is not written: it paints no pixel,
        and a closed subpath adds no winding to a point outside its bounding box, so the fill of the other
        subpaths of its path is unchanged (VectorGrid tiles carry a buffer beyond the tile clip, and the
        tiles at the edge of the map extend beyond the page);
      * a path filled with f* and painted again with S after an ExtGState that changes only stroke
        parameters (same /ca and /BM, no soft mask) is written once with B*, which is defined as that
        fill followed by that stroke.
    Lines the routine does not recognize are written unchanged; clips are tracked for axis-aligned
    transforms and single-rectangle clip paths only, anything else keeps the enclosing clip."""
    lines = content.split(b'\n')
    ctm, clip, stack = (1.0, 1.0, 0.0, 0.0), tuple(page_box), []
    items, path = [], []

    def dev_box(bb):
        a, d, e, f = ctm
        xs = (a * bb[0] + e, a * bb[2] + e)
        ys = (d * bb[1] + f, d * bb[3] + f)
        return min(xs), min(ys), max(xs), max(ys)

    for ln in lines:
        t = ln.split()
        if not t:
            items.append(('raw', ln))
            continue
        op = t[-1]
        if op in _PATH_OPS and not (op == b'h' and len(t) > 1):
            nums = [float(x) for x in t[:-1]]
            if op == b'm' or op == b're' or not path:
                path.append([[], [1e30, 1e30, -1e30, -1e30]])
            sp = path[-1]
            sp[0].append(ln)
            pts = ([(nums[0], nums[1]), (nums[0] + nums[2], nums[1] + nums[3])] if op == b're'
                   else list(zip(nums[0::2], nums[1::2])))
            for x, y in pts:
                sp[1][0] = min(sp[1][0], x); sp[1][1] = min(sp[1][1], y)
                sp[1][2] = max(sp[1][2], x); sp[1][3] = max(sp[1][3], y)
            continue
        if path and op in _PAINT_OPS and len(t) == 1:
            keep = []
            for sub, bb in path:
                if bb[0] > bb[2]:
                    keep.append(sub)
                    continue
                x0, y0, x1, y1 = dev_box((bb[0] - margin, bb[1] - margin, bb[2] + margin, bb[3] + margin))
                if x1 < clip[0] or x0 > clip[2] or y1 < clip[1] or y0 > clip[3]:
                    continue
                keep.append(sub)
            items.append(('path', keep, op))
            path = []
            continue
        if path and t[-2:] in ([b'W*', b'n'], [b'W', b'n']) and len(t) == 2:
            if len(path) == 1 and len(path[0][0]) == 1 and path[0][0][0].split()[-1] == b're':
                x0, y0, x1, y1 = dev_box(path[0][1])
                clip = (max(clip[0], x0), max(clip[1], y0), min(clip[2], x1), min(clip[3], y1))
            items.append(('raw', b'\n'.join(sum((s for s, _ in path), [])) + b'\n' + ln))
            path = []
            continue
        if path:  # a path ended by an operator this routine does not know: written unchanged
            items.append(('raw', b'\n'.join(sum((s for s, _ in path), []))))
            path = []
        if op == b'q':
            stack.append((ctm, clip))
        elif op == b'Q':
            ctm, clip = stack.pop()
        elif op == b'cm':
            a1, b1, c1, d1, e1, f1 = [float(x) for x in t[:6]]
            if b1 == 0 and c1 == 0:
                a0, d0, e0, f0 = ctm
                ctm = (a1 * a0, d1 * d0, e1 * a0 + e0, f1 * d0 + f0)
            else:  # a rotation: the clip is no longer tracked
                ctm, clip = (float('nan'),) * 4, (-1e30, -1e30, 1e30, 1e30)
        items.append(('raw', ln))
    assert not path

    def fill_same(g1, g2):
        a, b = gstates.get(g1), gstates.get(g2)
        if a is None or b is None or '/SMask' in a or '/SMask' in b:
            return False
        return all(str(a.get(k, '')) == str(b.get(k, '')) for k in ('/ca', '/BM'))

    out, i, gcur, merged = [], 0, None, 0
    while i < len(items):
        it = items[i]
        if (it[0] == 'path' and it[2] == b'f*' and i + 2 < len(items) and items[i + 1][0] == 'raw'
                and items[i + 1][1].endswith(b' gs') and items[i + 2][0] == 'path' and items[i + 2][2] == b'S'
                and items[i + 2][1] == it[1] and fill_same(gcur, items[i + 1][1].split()[0].decode())):
            gcur = items[i + 1][1].split()[0].decode()
            out.append(items[i + 1][1])
            if it[1]:
                out.extend(sum(it[1], []))
                out.append(b'B*')
            merged += 1
            i += 3
            continue
        if it[0] == 'raw':
            if it[1].endswith(b' gs'):
                gcur = it[1].split()[0].decode()
            out.append(it[1])
        elif it[1]:
            out.extend(sum(it[1], []))
            out.append(it[2])
        i += 1
    return b'\n'.join(out), merged


def simplify_pdf(pdf_in, pdf_out, tol, squeezed=False):
    """Simplify every run of line segments of the first page of pdf_in and of the forms it draws, with
    a tolerance of tol points of the page, and with `squeezed` rewrite the content of the page by
    #squeeze; write pdf_out, which may be pdf_in."""
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
    if squeezed:
        content = page.obj.Contents
        assert isinstance(content, pikepdf.Stream), 'one content stream expected'
        gs = {str(k): {str(a): str(b) for a, b in v.items()}
              for k, v in page.obj.Resources.get('/ExtGState', {}).items()}
        data = content.read_bytes()
        new, merged = squeeze(data, gs, [float(v) for v in page.mediabox])
        content.write(new)
        print(f'{pdf_in}: content {len(data)} -> {len(new)} bytes, {merged} fill+stroke pairs merged')
    pdf.save(pdf_out, compress_streams=True, object_stream_mode=pikepdf.ObjectStreamMode.generate)
    print(f'{pdf_in}: {counts[0]} line vertices -> {counts[1]} at {tol:.4f} pt')
    return counts


def simplify_printed(pdf, printed_w_mm, fraction=0.5, squeezed=False):
    """Simplify the map pdf in place at `fraction` of a pixel of the page as the book prints it
    `printed_w_mm` wide at 300 dpi, and with `squeezed` rewrite its page by #squeeze."""
    try:
        import pikepdf
        import shapely  # noqa: F401
    except ImportError:  # this Python has no pikepdf: simplify with the Python of PIKEPDF_PY
        subprocess.run([PIKEPDF_PY, os.path.abspath(__file__), pdf, pdf, str(printed_w_mm), str(fraction)]
                       + (['squeeze'] if squeezed else []), check=True)
        return
    with pikepdf.open(pdf) as p:
        box = [float(v) for v in p.pages[0].mediabox]
    simplify_pdf(pdf, pdf, print_tol(box[2] - box[0], printed_w_mm, fraction), squeezed)


if __name__ == '__main__':
    # pdf_simplify.py <in.pdf> <out.pdf> <printed width in mm> [fraction of a printed pixel, 0.5]
    #   [squeeze]
    import pikepdf
    with pikepdf.open(sys.argv[1]) as p:
        box = [float(v) for v in p.pages[0].mediabox]
    frac = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    simplify_pdf(sys.argv[1], sys.argv[2], print_tol(box[2] - box[0], float(sys.argv[3]), frac),
                 sys.argv[5:] == ['squeeze'])
