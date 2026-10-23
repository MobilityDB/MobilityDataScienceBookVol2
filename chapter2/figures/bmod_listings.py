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

"""Advanced PyMEOS section of chapter 2 (BerlinMOD-Brussels, 700 trips): runs the printed
listings in order on trips.csv, prints every value the chapter shows, and saves the matplotlib
figures pymeosbmod2_a ... pymeosbmod11_b but the maps pymeosbmod2_b and pymeosbmod6, and
pymeossimplifications* as PDF and PNG panels, and the values of pymeosbmod10 and pymeosbmod12
that fig_bmod_outputs.py renders. Code inside the listings is the chapter's code."""
import math
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('CH2_DATA', HERE / 'data'))  # input data, see README.md
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
from datetime import timedelta
from functools import partial
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['pdf.fonttype'] = 42
import matplotlib.pyplot as plt
from print_panels import CM, TEXTWIDTH, print_aligned, print_panel, print_grid
import distinctipy
import geopandas as gpd
import pandas as pd
import shapely.geometry as shp
from shapely import wkb
from pymeos import *
from pymeos.plotters import TemporalPointSequenceSetPlotter, TemporalPointSequencePlotter

D = DATA


# The size at which the book prints each panel (\includegraphics of chapter2.tex), whether it is a
# map, and the width of its lines: two panels side by side 0.44 of the text width wide and at most
# 6 cm high, #print_aligned of print_panels.py cutting their pages to the height of their maps (5.6 cm
# for Figs. 2.29 and 2.31), the three simplifications 0.3 of the text width, the first five trips 0.8
# of it
H6, H56, PAIR = 6 * CM, 5.6 * CM, 0.44 * TEXTWIDTH
BMOD2_B = (653, 678)  # the size of the map pymeosbmod2_b of fig_pymeosbmod2_b.py, in CSS px
PANELS = {
    'pymeosbmod2_a': (H56 * BMOD2_B[0] / BMOD2_B[1], H56, True, 0.3),
    # Fig. 2.30 at the size of the map pymeosbmod2_a of Fig. 2.29, over the same ground
    'pymeosbmod3_a': (H56 * BMOD2_B[0] / BMOD2_B[1], H56, True, 0.4),
    'pymeosbmod3_b': (H56 * BMOD2_B[0] / BMOD2_B[1], H56, True, 0.4),
    'pymeossimplifications_a': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeossimplifications_b': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeossimplifications_c': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeosbmod9_a': (PAIR, H6, True, 0.3), 'pymeosbmod9_b': (PAIR, H6, False, 0.5),
    'pymeosbmod5_a': (PAIR, H6, True, 0.4), 'pymeosbmod5_b': (PAIR, H6, False, 0.5),
    'pymeosbmod11_a': (PAIR, H6, True, 0.3), 'pymeosbmod11_b': (PAIR, H6, False, 0.3),
    'pymeosbmod7_a': (PAIR, H6, True, 0.3), 'pymeosbmod7_b': (PAIR, H6, False, 0.3),
}


# The extent aggregations (Figs. 2.34 and 2.35) and the tiles of Fig. 2.39: the map without a frame
# or margin, so that the blue rectangle of the spatial extent, or the grid of the tiles, is its only box, and the chart with room on both sides of the two red lines
# of the temporal extent; each panel names its lines in a legend under it
FRAMELESS = {'pymeosbmod9_a', 'pymeosbmod5_a', 'pymeosbmod7_a'}
MARGIN = {'pymeosbmod9_b': 0.08, 'pymeosbmod5_b': 0.08}
# name -> the limits (xmin, ymin, xmax, ymax) of a map in place of those of its data: the map of
# Fig. 2.38 has the ground of the grid of tiles of Fig. 2.39, so that the two figures have one size
BOUNDS = {}
EMPHASIS = {'pymeosbmod9_a': 'blue', 'pymeosbmod9_b': 'red', 'pymeosbmod5_a': 'blue',
            'pymeosbmod5_b': 'red'}
# The trips are timestamped in the time zone of Brussels (+02 in June): the time axes are labelled in it
TZ = 'Europe/Brussels'


def save_panels(fig, axes, names, ms=1.5):
    """Prints each axes as its panel at the size of PANELS, its markers at most ms points (None: as
    drawn): the panels of one figure, which have one page size, by #print_aligned of
    print_panels.py, so that their boxes have the same size and are aligned at the top, and a single
    panel by #print_panel."""
    panels = []
    for ax, name in zip(axes, names):
        width, height, map_, lw = PANELS[name]
        panels.append((ax, f'{OUT}/{name}.pdf', width, height,
                       dict(map_=map_, lw=lw, ms=ms, frame=name not in FRAMELESS,
                            margin=MARGIN.get(name, 0 if name in FRAMELESS else 0.03),
                            emphasis=EMPHASIS.get(name), tz=TZ,
                            **({'bounds': BOUNDS[name]} if name in BOUNDS else {}))))
    if len(panels) > 1:
        print_aligned(fig, panels)
    else:
        ax, path, width, height, style = panels[0]
        print_panel(fig, ax, path, width, height, **style)
    plt.close(fig)


def head(title, obj):
    print(f'=== {title}\n{obj}', flush=True)


pymeos_initialize()
trips = pd.read_csv(f'{D}/trips.csv', converters={'trip': TGeomPointSeq})
head('len(trips)', len(trips))
head('trips.tail', trips.tail(3))

records = trips.drop(columns="trip").copy()
records["geom"] = trips["trip"].apply(lambda tr: tr.values())
records["t"] = trips["trip"].apply(lambda tr: tr.timestamps())
records = records.explode(["geom", "t"], ignore_index=True)
records = records.sort_values("t")
head('records', f'{len(records)} rows; first {records.iloc[0].tolist()}')
del records

brussels = pd.read_csv(f'{D}/brussels_region.csv', converters={'geom': partial(wkb.loads, hex=True)})
brussels = gpd.GeoDataFrame(brussels, geometry='geom')
brussels_geom = brussels['geom'][0]
communes = pd.read_csv(f'{D}/brussels_communes.csv', converters={'geom': partial(wkb.loads, hex=True)})
communes['color'] = ['#00ff00', '#ff00ff', '#007fff', '#ff7f00', '#7fbf7f', '#47139e', '#ad0414',
    '#d981f9', '#138014', '#f4fc2c', '#00ffff', '#00ff7f', '#c04d7c', '#85eaf3', '#85d601',
    '#fca880', '#0000ff', '#019d92', '#907817']
communes = gpd.GeoDataFrame(communes, geometry='geom')

# pymeosbmod2_a (left panel of the chapter listing)
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
communes.plot(color=communes["color"], ax=axes[0], alpha=0.4)
TemporalPointSequencePlotter.plot_sequences_xy(
    trips["trip"], axes=axes[0], show_markers=False, show_grid=False)
# the extent of the map pymeosbmod2_b: the trajectories and the communes
bounds = gpd.GeoSeries(list(trips["trip"].apply(lambda tr: tr.to_shapely_geometry()))
    + list(communes.geometry)).total_bounds
axes[0].set_xlim(bounds[0], bounds[2]); axes[0].set_ylim(bounds[1], bounds[3])
save_panels(fig, axes[:1], ['pymeosbmod2_a'])

# Clipping
trips["trip"] = trips["trip"].apply(lambda tr: tr.set_srid(3857))
brussels_inout_trajectories = trips.copy()
brussels_inout_trajectories["inside"] = brussels_inout_trajectories["trip"].apply(
    lambda tr: tr.at(brussels_geom))
brussels_inout_trajectories["outside"] = brussels_inout_trajectories["trip"].apply(
    lambda tr: tr.minus(brussels_geom))
head('inside/outside non-null', (brussels_inout_trajectories["inside"].notna().sum(),
                                  brussels_inout_trajectories["outside"].notna().sum()))
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
brussels.plot(ax=axes[0], alpha=0.4)
for traj in brussels_inout_trajectories["inside"].dropna():
    if isinstance(traj, TGeomPointSeq):
        TemporalPointSequencePlotter.plot_xy(traj, axes=axes[0], show_markers=False, show_grid=False)
    else:
        TemporalPointSequenceSetPlotter.plot_xy(traj, axes=axes[0], show_markers=False, show_grid=False)
brussels.plot(ax=axes[1], alpha=0.4)
for traj in brussels_inout_trajectories["outside"].dropna():
    if isinstance(traj, TGeomPointSeq):
        TemporalPointSequencePlotter.plot_xy(traj, axes=axes[1], show_markers=False, show_grid=False)
    else:
        TemporalPointSequenceSetPlotter.plot_xy(traj, axes=axes[1], show_markers=False, show_grid=False)
# the extent of Fig. 2.29, so that the three maps show the same ground
for ax in axes:
    ax.set_xlim(bounds[0], bounds[2]); ax.set_ylim(bounds[1], bounds[3])
save_panels(fig, axes, ['pymeosbmod3_a', 'pymeosbmod3_b'])
del brussels_inout_trajectories

# Distance per commune
commune_trajectories = trips.copy()
for _, row in communes.iterrows():
    commune_trajectories[f'{row["name"]}-trajectory'] = commune_trajectories[
        "trip"].apply(lambda tr: tr.at(row["geom"]))
    commune_trajectories[f'{row["name"]}-distance'] = commune_trajectories[
        f'{row["name"]}-trajectory'].apply(lambda tr: tr.length() if tr else 0)
distances = commune_trajectories[["vehicle", "startdate", "seq", *(f"{commune}-distance"
    for commune in communes["name"])]]
head('commune distances (km, sum)', (distances.iloc[:, 3:].sum() / 1000).round(1).to_string())
matplotlib.rcParams['figure.max_open_warning'] = 0
fig, axes = plt.subplots(4, 5, figsize=(50, 40))
axes[0][0].set_title("Brussels Region")
communes.plot(color=communes["color"], ax=axes[0][0], alpha=0.4)
TemporalPointSequencePlotter.plot_sequences_xy(
    trips["trip"], axes=axes[0][0], show_markers=False, show_grid=False)
for i, commune in communes.iterrows():
    ax = axes[(i + 1) // 5][(i + 1) % 5]
    ax.set_title(commune["name"].split(" - ")[0])  # the French name
    if isinstance(commune["geom"], shp.Polygon):
        ax.fill(*commune["geom"].exterior.xy, color=commune["color"], alpha=0.4)
    else:
        for g in commune["geom"].geoms:
            ax.fill(*g.exterior.xy, color=commune["color"], alpha=0.4)
    trajs = commune_trajectories[f'{commune["name"]}-trajectory'].dropna()
    for traj in trajs:
        TemporalPointSequenceSetPlotter.plot_xy(traj, axes=ax, show_markers=False, show_grid=False)
# the figure shows the first two rows (the region and nine communes), at the text width
print_grid(fig, list(axes[0]) + list(axes[1]), f'{OUT}/pymeosbmod4.pdf', 5, TEXTWIDTH,
           0.19 * TEXTWIDTH, lw=0.3)
plt.close(fig)
del commune_trajectories

# Simplification
tolerance = 20
simplifications = trips.copy()
simplifications["dp"] = simplifications["trip"].apply(
    lambda tr: tr.simplify_douglas_peucker(tolerance))
simplifications["sed"] = simplifications["trip"].apply(
    lambda tr: tr.simplify_douglas_peucker(tolerance, synchronized=True))
# The instants that each simplification keeps of the trip 495, which the maps
# pymeossimplifications-trip_a, _b and _c of fig_pymeossimplifications_trip.py draw over the base map
east_west = simplifications.iloc[495]
for key, name in (("dp", "DP"), ("sed", "SED")):
    head(f'{name} instants of the trip 495',
         (east_west[key].num_instants(), east_west["trip"].num_instants()))
fig, axes = plt.subplots(1, 3, figsize=(30, 10))
for _, trip in simplifications.iterrows():
    trip["trip"].plot(axes=axes[0])
    trip["dp"].plot(axes=axes[1])
    trip["sed"].plot(axes=axes[2])
save_panels(fig, axes, ['pymeossimplifications_a', 'pymeossimplifications_b', 'pymeossimplifications_c'])
distances = simplifications[["vehicle", "startdate", "seq"]].copy()
distances["trip"] = simplifications["trip"].apply(lambda tr: tr.num_instants())
distances["dp"] = simplifications["dp"].apply(lambda tr: tr.num_instants())
distances["sed"] = simplifications["sed"].apply(lambda tr: tr.num_instants())
distances["dp-delta"] = distances["trip"] - distances["dp"]
distances["sed-delta"] = distances["trip"] - distances["sed"]
distances["dp-%"] = distances["dp"] * 100 / distances["trip"]
distances["sed-%"] = distances["sed"] * 100 / distances["trip"]
head('simplification head', distances.head().to_string())
head('simplification describe', distances[["dp-delta", "dp-%", "sed-delta", "sed-%"]].describe().to_string())
head('overall dp%, sed%', (distances["dp"].sum() * 100 / distances["trip"].sum(),
                           distances["sed"].sum() * 100 / distances["trip"].sum()))
del simplifications

# Aggregation
extent_bulk = TemporalPointExtentAggregator.aggregate(trips["trip"])
tcount_bulk = TemporalPeriodCountAggregator.aggregate(trips["trip"])
head('extent_bulk', extent_bulk)
head('tcount_bulk', str(tcount_bulk)[:700])
head('tcount_bulk max', tcount_bulk.max_value())
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
extent_bulk.plot_xy(axes=axes[0], color="blue", draw_filling=False, label="Spatial Extent")
for _, trip in trips.iterrows():
    trip["trip"].plot(axes=axes[0], show_markers=False)
tcount_bulk.plot(axes=axes[1], label="Temporal Count", color="g")
axes[1].axvline(extent_bulk.tmin(), color="red", label="Temporal Extent")
axes[1].axvline(extent_bulk.tmax(), color="red")
axes[0].legend()
axes[1].legend()
save_panels(fig, axes, ['pymeosbmod9_a', 'pymeosbmod9_b'])

day_trips = (trips["trip"]
    .apply(lambda tr: tr.at(TsTzSpan("[2020-06-01 08:00:00, 2020-06-01 12:00:00]")))
    .dropna())
day_extent = TemporalPointExtentAggregator.aggregate(day_trips)
day_tcount = TemporalPeriodCountAggregator.aggregate(day_trips)
head('len(day_trips)', len(day_trips))
head('day_extent', day_extent)
head('day_tcount', str(day_tcount)[:700])
head('day_tcount max', day_tcount.max_value())
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
day_extent.plot_xy(axes=axes[0], color="blue", draw_filling=False, label="Spatial Extent")
for trip in day_trips:
    trip.plot(axes=axes[0], show_markers=False)
day_tcount.plot(axes=axes[1], label="Temporal Count", color="g")
axes[1].axvline(day_extent.tmin(), color="red", label="Temporal Extent")
axes[1].axvline(day_extent.tmax(), color="red")
axes[0].legend()
axes[1].legend()
save_panels(fig, axes, ['pymeosbmod5_a', 'pymeosbmod5_b'])

extent_aggregator = TemporalPointExtentAggregator.start_aggregation()
count_aggregator = TemporalPeriodCountAggregator.start_aggregation()
for trip in trips["trip"]:
    extent_aggregator.add(trip)
    count_aggregator.add(trip)
extent_stream = extent_aggregator.aggregation()
count_stream = count_aggregator.aggregation()
head('stream == bulk', (str(extent_stream) == str(extent_bulk), str(count_stream) == str(tcount_bulk)))

# Tiling
tiled_trips = trips["trip"].apply(lambda tr: tr.tile(5e3, remove_empty=True))
speeds = trips["trip"].apply(lambda tr: tr.speed())
tiled_speeds = speeds.apply(lambda sp: sp.value_time_split(10, "1 day", 0, "2020-06-01"))
pd.set_option('display.width', 200)
head('tiled_trips', tiled_trips)
head('tiled_speeds', tiled_speeds)
with pd.option_context('display.max_colwidth', 50, 'display.max_rows', 10):
    tt = repr(tiled_trips).splitlines()[-5:]
    ts = repr(tiled_speeds).splitlines()[-4:]
with open(f'{OUT}/pymeosbmod10.txt', 'w') as f:
    f.write('\n'.join(tt) + '\n\n' + '\n'.join(ts) + '\n')
# The ground of the tiles of Fig. 2.39 for the map of Fig. 2.38, and for the speed charts of both the
# values up to the top of the speed tiles of 10 m/s that hold data
grid = extent_bulk.tile(5e3)
BOUNDS['pymeosbmod11_a'] = (min(t.xmin() for t in grid), min(t.ymin() for t in grid),
                            max(t.xmax() for t in grid), max(t.ymax() for t in grid))
SPEED_TOP = 10 * math.ceil(max(sp.max_value() for sp in speeds) / 10)
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
for tiled_trip in tiled_trips:
    for traj in tiled_trip:
        traj.plot(axes=axes[0], show_markers=False, rasterized=True)
for tiled_speed in tiled_speeds:
    for traj in tiled_speed:
        traj.plot(axes=axes[1], show_markers=False, rasterized=True)
axes[1].set_ylim(-0.03 * SPEED_TOP, SPEED_TOP)
save_panels(fig, axes, ['pymeosbmod11_a', 'pymeosbmod11_b'])
del tiled_trips, tiled_speeds

extent_tiles = extent_bulk.tile(5e3)
speed_extent = TemporalNumberExtentAggregator.aggregate(speeds)
speed_tiles = speed_extent.tile(10, "1 day", 0.0, "2020-06-01")
head('speed_extent', speed_extent)
head('#extent_tiles, #speed_tiles', (len(extent_tiles), len(speed_tiles)))
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
for tile, color in zip(extent_tiles, distinctipy.get_colors(len(extent_tiles), rng=0)):
    tile.plot_xy(axes=axes[0], color="black", draw_filling=False)
    for trip in trips["trip"]:
        trip_in_tile = trip.at(tile)
        if trip_in_tile is not None:
            trip_in_tile.plot(axes=axes[0], color=color, show_markers=False, rasterized=True)
for tile, color in zip(speed_tiles, distinctipy.get_colors(len(speed_tiles), rng=0)):
    tile.plot(axes=axes[1], color="black", draw_filling=False)
    for speed in speeds:
        speed_in_tile = speed.at(tile)
        if speed_in_tile is not None:
            speed_in_tile.plot(axes=axes[1], color=color, show_markers=False, rasterized=True)
axes[1].set_ylim(-0.03 * SPEED_TOP, SPEED_TOP)
save_panels(fig, axes, ['pymeosbmod7_a', 'pymeosbmod7_b'])

data = []
for tile in extent_tiles:
    intersections = trips["trip"].apply(lambda tr: tr.at(tile)).dropna()
    if len(intersections) == 0:
        continue
    count = len(intersections)
    duration = sum([i.duration() for i in intersections], timedelta())
    distance = sum([i.length() for i in intersections]) / 1000
    data.append([tile, count, duration, distance])
spatial_aggregates = pd.DataFrame(data, columns=["tile", "count", "duration", "distance"])
head('spatial_aggregates', spatial_aggregates.to_string(max_colwidth=45))
spatial_aggregates.assign(tile=spatial_aggregates.tile.astype(str)).to_csv(f'{OUT}/spatial_aggregates.csv', index=False)

data = []
for tile in speed_tiles:
    intersections = speeds.apply(lambda tr: tr.at(tile)).dropna()
    if len(intersections) == 0:
        continue
    count = len(intersections)
    duration = sum([i.duration() for i in intersections], timedelta())
    data.append([tile, count, duration])
speed_aggregates = pd.DataFrame(data, columns=["tile", "count", "duration"])
head('speed_aggregates', speed_aggregates.to_string(max_colwidth=45))
speed_aggregates.assign(tile=speed_aggregates.tile.astype(str)).to_csv(f'{OUT}/speed_aggregates.csv', index=False)
pymeos_finalize()
print('DONE')
