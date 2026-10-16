"""Write the layers and the QGIS jobs of the three maps of the Atlantic storms of 2024 of Fig.
storms of chapter 3, which storms_qgis_map.py draws: storms_tpoint (the tracks), storms_tgeo (the
wind fields) and storms_tcbuffer (the areas the temporal circular buffers traverse).

The layers are read from the tables that storms/storms.sql builds with year=2024. The three maps
share one extent in longitude and latitude (EPSG:4326), which takes in every track, wind field and
traversed area with a margin of about 2 degrees. Each map draws the tracks of the storms and their
observations; the map of the wind fields draws over them the wind radii polygons of 34, 50 and 64
knots, and the map of the temporal circular buffers the area that each one traverses, filled with
a transparent color so that each one shows through the others.
Usage: python3 storms_jobs.py <database> <out>
  The connection parameters other than the database are read from the environment variables of
  psql (PGHOST, PGPORT, PGUSER).
"""
import json
import os
import subprocess
import sys

DB, OUT = sys.argv[1], sys.argv[2]
PSQL = ["psql", "-X", "-At", "-v", "ON_ERROR_STOP=1", "-d", DB]
DPI = 300
LAND, WATER, BORDER = "#f2efe9", "#aad3df", "#a29cb4"
WIDTH = 1242                     # 300 dpi pixels of the printed width of the maps
EXTENT = [-105.0, 11.1186, 6.5, 60.5]
SIZE = [WIDTH, round(WIDTH * (EXTENT[3] - EXTENT[2]) / (EXTENT[1] - EXTENT[0]))]


def collection(path, query):
    """Write a GeoJSON file of the geometries of query (geometry, order), in that order."""
    sql = ("SELECT json_build_object('type', 'FeatureCollection', 'features', "
           "json_agg(json_build_object('type', 'Feature', 'properties', '{}'::json, "
           f"'geometry', ST_AsGeoJSON(g, 6)::json) ORDER BY o)) FROM ({query}) AS q(g, o)")
    with open(path, "w") as f:
        f.write(subprocess.run(PSQL + ["-c", sql], check=True, capture_output=True,
                               text=True).stdout)


collection(os.path.join(OUT, "tracks.geojson"),
           "SELECT Traj, substr(StormId, 3, 2)::integer FROM Storms2024_tpoint")
collection(os.path.join(OUT, "points.geojson"),
           "SELECT Geom, row_number() OVER (ORDER BY StormId, T) FROM StormPoints")
# The polygons and the traversed areas from the 34-knot threshold to the 64-knot one, so that the
# stronger winds are drawn over the weaker ones
collection(os.path.join(OUT, "radii.geojson"),
           "SELECT Geom, row_number() OVER (ORDER BY Radii, T, StormId) FROM StormRadii")
collection(os.path.join(OUT, "tcbuffers.geojson"),
           "SELECT ST_CollectionExtract(ST_CurveToLine(Trav, 64), 3), "
           "row_number() OVER (ORDER BY Radii, substr(StormId, 3, 2)::integer) "
           "FROM Storms2024_tcbuffer")

base = {"type": "shortbread", "water": WATER, "streets": None, "buildings": None,
        "border": BORDER, "border_style": "solid", "border_width": 0.2, "border_admin_level": 2,
        "border_land_only": True, "water_min_area": 1e9, "water_lines": False}
tracks = [
    {"path": "tracks.geojson", "kind": "line",
     "style": {"line_color": "#ff0000", "line_width": "0.5", "capstyle": "round",
               "joinstyle": "round"}},
    {"path": "points.geojson", "kind": "marker",
     "style": {"name": "circle", "color": "#ff0000", "outline_color": "#ff0000",
               "outline_width": "0.11", "size": "0.89"}},
]
radii = {"path": "radii.geojson", "kind": "fill",
         "style": {"color": "#ffa0a0", "outline_color": "#ff0000", "outline_width": "0.12"}}
tcbuffers = {"path": "tcbuffers.geojson", "kind": "fill",
             "style": {"color": "255,60,60,60", "outline_color": "255,0,0,255",
                       "outline_width": "0.15"}}
for name, layers in (("storms_tpoint", tracks), ("storms_tgeo", tracks + [radii]),
                     ("storms_tcbuffer", tracks + [tcbuffers])):
    spec = {"output": f"{name}.pdf", "crs": "EPSG:4326", "extent": EXTENT, "size": SIZE,
            "dpi": DPI, "land": LAND, "basemap_oversample": 8, "layers": [base] + layers}
    json.dump(spec, open(os.path.join(OUT, f"{name}.json"), "w"), indent=1)

# The map of Query 3.1, around Tampa in the UTM zone 17N (EPSG:32617), its layers in longitude
# and latitude as GeoJSON requires and its texts in the coordinates of the map: the wind fields of 50 and
# 64 knots of Milton at 2:30 on October 10, the values observed at 0:00, dotted the field of 64
# knots observed next, at 6:00, the track of Milton from 6:00 on October 9 to 18:00 on October 10
# with its observations, and Tampa
UTM = 32617
T = "'2024-10-10 02:30+00'"
SPAN = "tstzspan '[2024-10-09 06:00+00, 2024-10-10 18:00+00]'"
collection(os.path.join(OUT, "tampa_fields.geojson"),
           f"SELECT valueAtTimestamp(Storm, {T})::geometry, Radii "
           "FROM Storms2024_tgeo WHERE Name = 'Milton' AND Radii >= 50")
collection(os.path.join(OUT, "tampa_next.geojson"),
           "SELECT valueAtTimestamp(Storm, '2024-10-10 06:00+00')::geometry, 1 "
           "FROM Storms2024_tgeo WHERE Name = 'Milton' AND Radii = 64")
collection(os.path.join(OUT, "tampa_track.geojson"),
           f"SELECT trajectory(atTime(Storm, {SPAN})), 1 "
           "FROM Storms2024_tpoint WHERE Name = 'Milton'")
collection(os.path.join(OUT, "tampa_points.geojson"),
           "SELECT getValue(i), getTimestamp(i) "
           f"FROM Storms2024_tpoint, unnest(instants(atTime(Storm, {SPAN}))) i "
           "WHERE Name = 'Milton'")
collection(os.path.join(OUT, "tampa_city.geojson"),
           "SELECT ST_Point(-82.46, 27.95, 4326), 1")


def utm(lon, lat):
    """The coordinates in the UTM zone 17N of a point given in longitude and latitude."""
    out = subprocess.run(PSQL + ["-F", " ", "-c",
                         f"SELECT ST_X(g), ST_Y(g) FROM ST_Transform(ST_Point({lon}, {lat}, 4326), "
                         f"{UTM}) g"], check=True, capture_output=True, text=True).stdout
    return [float(v) for v in out.split()]


def observation(t):
    """The position of Milton at the observation t, in longitude and latitude."""
    out = subprocess.run(PSQL + ["-F", " ", "-c",
                         f"SELECT ST_X(g), ST_Y(g) FROM (SELECT valueAtTimestamp(Storm, '{t}') g "
                         "FROM Storms2024_tpoint WHERE Name = 'Milton') q"],
                         check=True, capture_output=True, text=True).stdout
    return [float(v) for v in out.split()]


# The texts are of 9.5 points on the map of 1243 pixels, which the book prints at 0.8\textwidth, so
# that they are of the size of the caption
TEXT = 9.5
texts = []
for label, where, anchor in (("Tampa", (-82.46, 27.95), "right"),
                             ("Oct 9, 18:00", observation("2024-10-09 18:00+00"), "right"),
                             ("Oct 10, 0:00", observation("2024-10-10 00:00+00"), "left"),
                             ("6:00", observation("2024-10-10 06:00+00"), "right"),
                             ("64 kt", (-82.45, 26.98), "above"),
                             ("50 kt", (-83.95, 27.55), "above")):
    x, y = utm(*where)
    texts.append({"text": label, "x": x, "y": y, "anchor": anchor, "gap": 3, "size": TEXT})
tampa = [
    {"path": "tampa_fields.geojson", "kind": "fill",
     "style": {"color": "255,60,60,60", "outline_color": "255,0,0,255", "outline_width": "0.15"}},
    {"path": "tampa_next.geojson", "kind": "fill",
     "style": {"color": "0,0,0,0", "outline_color": "255,0,0,255", "outline_width": "0.3",
               "outline_style": "dot"}},
    {"path": "tampa_track.geojson", "kind": "line",
     "style": {"line_color": "#ff0000", "line_width": "0.5", "capstyle": "round",
               "joinstyle": "round"}},
    {"path": "tampa_points.geojson", "kind": "marker",
     "style": {"name": "circle", "color": "#ff0000", "outline_color": "#ff0000",
               "outline_width": "0.11", "size": "1.3"}},
    {"path": "tampa_city.geojson", "kind": "marker",
     "style": {"name": "circle", "color": "#000000", "outline_color": "#000000",
               "outline_width": "0.05", "size": "1.0"}},
]
tampa_base = dict(base, water_min_area=2e7)
spec = {"output": "storms_tampa.pdf", "crs": f"EPSG:{UTM}",
        "extent": [175000, 525000, 2880000, 3185000], "size": [1243, 1083], "dpi": DPI,
        "land": LAND, "basemap_oversample": 4, "layers": [tampa_base] + tampa, "texts": texts}
json.dump(spec, open(os.path.join(OUT, "storms_tampa.json"), "w"), indent=1)
print("wrote", OUT, SIZE)
