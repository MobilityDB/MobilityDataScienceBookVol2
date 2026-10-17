"""Write, for each map figure of a spec of figlib.py (spec_ais.json, spec_nuscenes.json), the job
job_<figure>.json that chapter3/figures/storms_qgis_map.py draws as the vector PDF <figure>.pdf,
as chapter3/figures/noise_region_job.py writes the job of a map of vessels of chapter 3: the
OpenStreetMap Shortbread basemap of the book with its buildings and streets, the extent of the
spec in EPSG:3857 with the height that keeps its proportions, and the layers of the spec bottom
to top (the spec lists them top first), each with the style of the spec as a QGIS symbol; a
layer without features is left out. render.sh draws the jobs.

Usage: python3 spec_jobs.py <spec.json>     (in $OUT, where the GeoJSON layers are)
"""
import json
import math
import os
import sys

DPI = 300
LAND, WATER = "#f2efe9", "#aad3df"
BASE = {"type": "shortbread", "water": WATER, "streets": "#ffffff", "buildings": "#d9d0c9",
        "border": None}
R = 6378137.0


def merc(lon, lat):
    """A longitude and a latitude in EPSG:3857"""
    return R * math.radians(lon), R * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))


def layer(spec):
    """A layer of a job of storms_qgis_map.py from a layer of a spec of figlib.py"""
    kind = spec["type"]
    if kind == "polygon":
        style = {"color": spec.get("fill", "0,0,255,80"),
                 "outline_color": spec.get("stroke", "0,0,0,255"),
                 "outline_width": str(spec.get("width", 0.3)),
                 "outline_style": spec.get("style", "solid")}
        return {"path": spec["file"], "kind": "fill", "style": style}
    if kind == "line":
        style = {"line_color": spec.get("stroke", "0,0,255,255"),
                 "line_width": str(spec.get("width", 0.6)),
                 "line_style": spec.get("style", "solid"), "capstyle": "round"}
        return {"path": spec["file"], "kind": "line", "style": style}
    style = {"name": spec.get("shape", "circle"), "color": spec.get("fill", "255,0,0,255"),
             "outline_color": spec.get("stroke", "0,0,0,255"), "size": str(spec.get("size", 1.5))}
    return {"path": spec["file"], "kind": "marker", "style": style}


for fig in json.load(open(sys.argv[1])):
    x0, y0 = merc(*fig["extent"][:2])
    x1, y1 = merc(*fig["extent"][2:])
    width = fig.get("width", 1800)
    height = round(width * (y1 - y0) / (x1 - x0))
    layers = [layer(s) for s in reversed(fig["layers"])
              if json.load(open(s["file"]))["features"]]
    name = os.path.splitext(fig["out"])[0]
    job = {"output": f"{name}.pdf", "crs": "EPSG:3857", "extent": [x0, x1, y0, y1],
           "size": [width, height], "dpi": DPI, "land": LAND,
           "layers": [BASE] + layers}
    json.dump(job, open(f"job_{name}.json", "w"), indent=1)
    print(f"job_{name}.json", width, height, len(layers), "layers")
