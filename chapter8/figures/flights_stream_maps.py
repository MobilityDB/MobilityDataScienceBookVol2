"""Write the maps of the stream queries of the chapter Mobility Streams, as
flights_queries_maps.py writes those of the queries of the chapter Large-Scale Mobility
Databases, whose #features and #job layers it reuses.

    python flights_stream_maps.py <topics> <out>   then  render.sh <out>

<topics> holds the dumps of the Kafka topics hourly-trips and brussels-arrivals that the job
flights_queries.py of chapter9/Flink_Examples/flights_stream writes, one JSON message per line,
whose trajectories and origins are in HexEWKB, the form in which Flink, which has no spatial
library, passes a geometry on; shapely reads them. flightsStreamQuery1 draws the trajectories of
the window from 8 to 9 o'clock, as one image of 300 dpi as flightsQuery1; flightsStreamQuery2
draws the routes of the arrivals at Brussels as one image and their origins as vectors, as
flightsQuery2 draws the departures.
"""
import json
import sys

from shapely import wkb

from flights_queries_maps import (ARRIVALS_COLOR, EUROPE, FLIGHTS_COLOR, MAPWIDTH, features,
                                  inside)
from mapjob import extent3857, job

TOPICS, OUT = sys.argv[1], sys.argv[2]


def messages(topic):
    with open(f"{TOPICS}/{topic}.json") as f:
        return [json.loads(line) for line in f if line.strip()]


def query1():
    rows = [m for m in messages("hourly-trips") if m["window_start"].startswith("2026-03-01 08:00")]
    features(f"{OUT}/flightsStreamQuery1_trips.geojson",
             [(wkb.loads(m["trajectory"], hex=True), {}) for m in rows])
    job(OUT, "flightsStreamQuery1", extent3857(*EUROPE), MAPWIDTH, [
        {"path": "flightsStreamQuery1_trips.geojson", "kind": "line", "image": True,
         "style": {"line_color": FLIGHTS_COLOR, "line_width": "0.12"}}],
        streets=None, border="#9a9a9a")
    return len(rows)


def query2():
    rows = messages("brussels-arrivals")
    origins = [wkb.loads(m["origin"], hex=True) for m in rows]
    features(f"{OUT}/flightsStreamQuery2_routes.geojson",
             [(wkb.loads(m["route"], hex=True), {}) for m in rows])
    features(f"{OUT}/flightsStreamQuery2_origins.geojson", [(p, {}) for p in origins])
    job(OUT, "flightsStreamQuery2", extent3857(*EUROPE), MAPWIDTH, [
        {"path": "flightsStreamQuery2_routes.geojson", "kind": "line", "image": True,
         "style": {"line_color": ARRIVALS_COLOR, "line_width": "0.15"}},
        {"path": "flightsStreamQuery2_origins.geojson", "kind": "marker",
         "style": {"name": "circle", "color": "0,0,0,255", "outline_style": "no", "size": "0.6"}}],
        streets=None, border="#9a9a9a")
    outside = sum(not inside(p.x, p.y, EUROPE) for p in origins)
    return len(rows), outside


if __name__ == "__main__":
    print("query 1: trajectories of 8 to 9 o'clock", query1())
    print("query 2: arrivals, origins outside the map", query2())
