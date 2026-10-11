"""Write the four Citi Bike maps of the chapter Large-Scale Mobility Databases as QGIS jobs.

    python citibike_maps.py <data> <out>        then  render.sh <out>/<map>.json

The chapter draws them with pydeck; these static versions draw the same points, colors and
eight quantile classes of the pydeck code of the chapter, from the CSV directories that
export_maps.sql writes into <data>. For each map this writes its data layers as GeoJSON, its
job for qgis_map.py (#job of mapjob.py: the Shortbread basemap of the book as one image of
300 dpi of the printed width, the stations and the buffer as vectors on top) and its LaTeX
overlay, <map>_overlay.tex: the map carries no text, its legend and its labels are set in the
style of the captions, as #main of chapter5/figures/overlay_depth_under_vessel.py writes the
overlay of the figure of the depth under the vessel, so that each figure and its caption share
their font and their size. The captions credit the basemap.
"""
import glob
import sys

import pandas as pd

from mapjob import TO3857, geometry, job, padded, points, rgba

DATA, OUT = sys.argv[1], sys.argv[2]
TEXTWIDTH = 11.7 / 2.54          # inches
PALETTE = {1: [255, 245, 245, 200], 2: [250, 222, 211, 200], 3: [255, 180, 203, 200],
           4: [255, 150, 211, 200], 5: [245, 120, 103, 200], 6: [211, 80, 50, 200],
           7: [180, 40, 30, 200], 8: [115, 0, 0, 200]}


def read(name):
    return pd.concat(pd.read_csv(f) for f in glob.glob(f"{DATA}/{name}/*.csv"))


def project(df):
    x, y = TO3857.transform(df["lon"].values, df["lat"].values)
    return df.assign(x=x, y=y)


def tikz_open(image, width):
    return ["\\begin{tikzpicture}",
            "\\node[anchor=south west, inner sep=0] (img) "
            "{\\includegraphics[width=%s]{%s}};" % (width, image)]


def stations_map(width):
    df = project(read("stations"))
    points(f"{OUT}/nycstations_stations.geojson", df.lon, df.lat)
    job(OUT, "nycstations", padded(df.x, df.y, 1500), width, [
        {"path": "nycstations_stations.geojson", "kind": "marker",
         "style": {"name": "circle", "color": "0,120,255,255", "outline_style": "no", "size": "0.45"}}])
    return len(df)


def choropleth(name, out, title, width, tex_width):
    df = project(read(name))
    q, bins = pd.qcut(df["no_trips"], q=8, labels=False, retbins=True, duplicates="drop")
    df["quantile_class"] = q + 1
    df = df.sort_values("no_trips")
    stations = project(read("stations"))
    stem = out[:-4]
    points(f"{OUT}/{stem}_stations.geojson", df.lon, df.lat,
           [rgba(PALETTE[int(k)]) for k in df["quantile_class"]])
    job(OUT, stem, padded(stations.x, stations.y, 1200), width, [
        {"path": f"{stem}_stations.geojson", "kind": "marker", "color_field": "color",
         "style": {"name": "circle", "color": "200,200,200,200", "outline_color": "100,100,100,255",
                   "outline_width": "0.04", "size": "0.5"}}])
    # The legend, below the image so that it hides no station: its title and,
    # in two columns, one dot of the color of each class and its range of trips.
    lines = [f"% Written by citibike_maps.py from the quantile classes of {name}."]
    lines += ["\\definecolor{%sc%d}{RGB}{%d,%d,%d}" % (stem, k, *PALETTE[k][:3]) for k in PALETTE]
    lines += tikz_open(f"figs/chap8/{out}", tex_width)
    lines += ["\\node[anchor=north west, inner sep=0pt, font=\\captionstyle] "
              "at ([yshift=-3pt]img.south west) {%",
              "\\begin{tabular}{@{}c@{\\hspace{2pt}}r@{\\,--\\,}l@{\\hspace{6pt}}c@{\\hspace{2pt}}r@{\\,--\\,}l@{}}",
              "\\multicolumn{6}{@{}l@{}}{%s} \\\\" % title]
    items = ["\\tikz\\draw[fill=%sc%d, fill opacity=0.8, draw=black!60, line width=0.2pt] "
             "(0,0) circle (1.6pt); & %s & %s"
             % (stem, k + 1, f"{int(bins[k]):,}".replace(",", "\\,"),
                f"{int(bins[k + 1]):,}".replace(",", "\\,"))
             for k in range(len(bins) - 1)]
    half = (len(items) + 1) // 2
    for k in range(half):
        right = items[k + half] if k + half < len(items) else "& &"
        lines.append(f"{items[k]} & {right} \\\\")
    lines += ["\\end{tabular}};", "\\end{tikzpicture}"]
    open(f"{OUT}/{stem}_overlay.tex", "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return len(df), [int(b) for b in bins]


def columbus_map(width, tex_width):
    from shapely import wkt
    df = project(read("columbus"))
    buf = wkt.loads(read("columbus_buffer")["wkt"].iloc[0])
    bx, by = TO3857.transform(*buf.exterior.xy)
    x0, x1, y0, y1 = extent = padded(bx, by, 60)
    geometry(f"{OUT}/columbus_buffer.geojson",
             {"type": "LineString", "coordinates": [list(c) for c in buf.exterior.coords]})
    points(f"{OUT}/columbus_stations.geojson", df.lon, df.lat)
    job(OUT, "columbus", extent, width, [
        {"path": "columbus_buffer.geojson", "kind": "line",
         "style": {"line_color": "184,214,46,255", "line_width": "0.42"}},
        {"path": "columbus_stations.geojson", "kind": "marker",
         "style": {"name": "circle", "color": "220,20,60,255", "outline_style": "no", "size": "1.65"}}],
        buildings="#d9d0c9")
    # The ratio of each station beside its dot.
    lines = ["% Written by citibike_maps.py from the ratios of the stations near Columbus Circle."]
    lines += tikz_open("figs/chap8/columbus.pdf", tex_width)
    lines.append("\\begin{scope}[x={(img.south east)}, y={(img.north west)}, font=\\captionstyle]")
    # Two stations at the same place (7 Ave & Central Park South and its pillar) stack their
    # labels, one line apart, so that neither hides the other
    placed = []
    for _, r in df.sort_values("station").iterrows():
        fx, fy = (r.x - x0) / (x1 - x0), (r.y - y0) / (y1 - y0)
        stacked = sum(abs(fx - px) < 0.005 and abs(fy - py) < 0.005 for px, py in placed)
        placed.append((fx, fy))
        lines.append("\\node[anchor=south west, fill=white, fill opacity=0.85, text opacity=1, "
                     "inner sep=1pt] at (%.4f, %.4f) {%.2f};"
                     % (fx + 0.012, fy + 0.008 - 0.045 * stacked, r["ratio"]))
    lines += ["\\end{scope}", "\\end{tikzpicture}"]
    open(f"{OUT}/columbus_overlay.tex", "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return df[["station", "no_start_trips", "no_end_trips", "ratio"]].sort_values("station")


if __name__ == "__main__":
    print("stations", stations_map(0.6 * TEXTWIDTH))
    # Each choropleth fills a minipage of 0.48\\textwidth, whose \\linewidth it takes.
    print("start", choropleth("start_trips", "map1new.pdf", "Trips per station",
                              0.48 * TEXTWIDTH, "\\linewidth"))
    print("dest", choropleth("afternoon_dest", "map2new.pdf", "Afternoon trips",
                             0.48 * TEXTWIDTH, "\\linewidth"))
    print(columbus_map(0.64 * TEXTWIDTH, "0.64\\textwidth").to_string(index=False))
