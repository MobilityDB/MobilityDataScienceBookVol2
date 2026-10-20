"""Advanced PyMEOS section of chapter 2 (BerlinMOD-Brussels, 700 trips): runs the printed
listings in order on trips.csv, prints every value the chapter shows, and saves the matplotlib
figures pymeosbmod2_a ... pymeosbmod11_b but the maps pymeosbmod2_b and pymeosbmod6, and
pymeossimplifications* as PDF and PNG panels, and the values of pymeosbmod10 and pymeosbmod12
that fig_bmod_outputs.py renders. Code inside the listings is the chapter's code."""
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
from print_panels import CM, TEXTWIDTH, print_panel, print_grid
import distinctipy
import geopandas as gpd
import pandas as pd
import shapely.geometry as shp
from shapely import wkb
from pymeos import *
from pymeos.plotters import TemporalPointSequenceSetPlotter, TemporalPointSequencePlotter

D = DATA


# The size at which the book prints each panel (\includegraphics of chapter2.tex), whether it is a
# map, and the width of its lines: two panels side by side 6 cm high (5.6 cm for Figs. 2.30 and
# 2.31), the three simplifications 0.3 of the text width, the first five trips 0.8 of it
H6, H56, PAIR = 6 * CM, 5.6 * CM, 0.44 * TEXTWIDTH
BMOD2_B = (653, 678)  # the size of the map pymeosbmod2_b of fig_pymeosbmod2_b.py, in CSS px
PANELS = {
    'pymeosbmod2_a': (H56 * BMOD2_B[0] / BMOD2_B[1], H56, True, 0.3),
    'pymeosbmod3_a': (PAIR, H56, True, 0.4), 'pymeosbmod3_b': (PAIR, H56, True, 0.4),
    'pymeossimplifications-firstfive': (0.8 * TEXTWIDTH, 0.42 * TEXTWIDTH, True, 0.6),
    'pymeossimplifications_a': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeossimplifications_b': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeossimplifications_c': (0.3 * TEXTWIDTH, 0.345 * TEXTWIDTH, True, 0.25),
    'pymeosbmod9_a': (PAIR, H6, True, 0.3), 'pymeosbmod9_b': (PAIR, H6, False, 0.5),
    'pymeosbmod5_a': (PAIR, H6, True, 0.4), 'pymeosbmod5_b': (PAIR, H6, False, 0.5),
    'pymeosbmod11_a': (PAIR, H6, True, 0.3), 'pymeosbmod11_b': (PAIR, H6, False, 0.3),
    'pymeosbmod7_a': (PAIR, H6, True, 0.3), 'pymeosbmod7_b': (PAIR, H6, False, 0.3),
}


def save_panels(fig, axes, names):
    """Prints each axes as its panel by #print_panel of print_panels.py, at the size of PANELS."""
    for ax, name in zip(axes, names):
        width, height, map_, lw = PANELS[name]
        print_panel(fig, ax, f'{OUT}/{name}.pdf', width, height, map_=map_, lw=lw, ms=1.5)
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
axes[0].set_title("Inside Brussels")
brussels.plot(ax=axes[0], alpha=0.4)
for traj in brussels_inout_trajectories["inside"].dropna():
    if isinstance(traj, TGeomPointSeq):
        TemporalPointSequencePlotter.plot_xy(traj, axes=axes[0], show_markers=False, show_grid=False)
    else:
        TemporalPointSequenceSetPlotter.plot_xy(traj, axes=axes[0], show_markers=False, show_grid=False)
axes[1].set_title("Outside Brussels")
brussels.plot(ax=axes[1], alpha=0.4)
for traj in brussels_inout_trajectories["outside"].dropna():
    if isinstance(traj, TGeomPointSeq):
        TemporalPointSequencePlotter.plot_xy(traj, axes=axes[1], show_markers=False, show_grid=False)
    else:
        TemporalPointSequenceSetPlotter.plot_xy(traj, axes=axes[1], show_markers=False, show_grid=False)
axes[0].set_xlim(min(axes[0].get_xlim()[0], axes[1].get_xlim()[0]),
                 max(axes[0].get_xlim()[1], axes[1].get_xlim()[1]))
axes[0].set_ylim(min(axes[0].get_ylim()[0], axes[1].get_ylim()[0]),
                 max(axes[0].get_ylim()[1], axes[1].get_ylim()[1]))
axes[1].set_xlim(axes[0].get_xlim()); axes[1].set_ylim(axes[0].get_ylim())
save_panels(fig, axes, ['pymeosbmod3_a', 'pymeosbmod3_b'])
del brussels_inout_trajectories

# Distance per commune
commune_trajectories = trips.copy()
for _, row in communes.iterrows():
    commune_trajectories[f'{row["name"]}-trajectory'] = commune_trajectories[
        "trip"].apply(lambda tr: tr.at(row["geom"]))
    commune_trajectories[f'{row["name"]}-distance'] = commune_trajectories[
        f'{row["name"]}-trajectory'].apply(lambda tr: tr.length() if tr else 0)
distances = commune_trajectories[["vehicle", "day", "seq", *(f"{commune}-distance"
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
    ax.set_title(commune["name"])
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
# pymeossimplifications-firstfive: original (grey), DP (red), SED (blue) of the first five trips
fig, ax = plt.subplots(figsize=(20, 10))
for i in range(5):
    s = simplifications.iloc[i]
    ax.plot(*zip(*[(p.x, p.y) for p in s["trip"].values()]), color='grey', lw=1,
            label='Original' if i == 0 else None)
    ax.plot(*zip(*[(p.x, p.y) for p in s["sed"].values()]), 's', color='blue', ms=3,
            label='SED' if i == 0 else None)
    ax.plot(*zip(*[(p.x, p.y) for p in s["dp"].values()]), 'o', color='red', ms=4,
            label='DP' if i == 0 else None)
ax.legend(loc="lower right")
save_panels(fig, [ax], ['pymeossimplifications-firstfive'])
fig, axes = plt.subplots(1, 3, figsize=(30, 10))
for _, trip in simplifications.iterrows():
    trip["trip"].plot(axes=axes[0])
    trip["dp"].plot(axes=axes[1])
    trip["sed"].plot(axes=axes[2])
save_panels(fig, axes, ['pymeossimplifications_a', 'pymeossimplifications_b', 'pymeossimplifications_c'])
distances = simplifications[["vehicle", "day", "seq"]].copy()
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
extent_bulk.plot_xy(axes=axes[0], label="Spatial Extent")
for _, trip in trips.iterrows():
    trip["trip"].plot(axes=axes[0], show_markers=False)
axes[0].set_title("Spatial Extent")
tcount_bulk.plot(axes=axes[1], label="Temporal Count", color="g")
extent_bulk.to_tstzspan().plot(axes=axes[1], label="Temporal Extent")
axes[1].set_title("Temporal Count + Temporal Extent")
plt.legend()
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
day_extent.plot_xy(axes=axes[0], label="Spatial Extent")
for trip in day_trips:
    trip.plot(axes=axes[0], show_markers=False)
axes[0].set_title("Spatial Extent")
day_tcount.plot(axes=axes[1], label="Temporal Count", color="g")
day_extent.to_tstzspan().plot(axes=axes[1], label="Temporal Extent")
axes[1].set_title("Temporal Count + Temporal Extent")
plt.legend()
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
fig, axes = plt.subplots(1, 2, figsize=(20, 10))
for tiled_trip in tiled_trips:
    for traj in tiled_trip:
        traj.plot(axes=axes[0], show_markers=False, rasterized=True)
axes[0].set_title("Tiled Trajectories")
for tiled_speed in tiled_speeds:
    for traj in tiled_speed:
        traj.plot(axes=axes[1], show_markers=False, rasterized=True)
axes[1].set_title("Tiled Speeds")
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
axes[0].set_title("Tiled Trajectories")
for tile, color in zip(speed_tiles, distinctipy.get_colors(len(speed_tiles), rng=0)):
    tile.plot(axes=axes[1], color="black", draw_filling=False)
    for speed in speeds:
        speed_in_tile = speed.at(tile)
        if speed_in_tile is not None:
            speed_in_tile.plot(axes=axes[1], color=color, show_markers=False, rasterized=True)
axes[1].set_title("Tiled Speeds")
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
