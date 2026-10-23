"""The view shared by the three maps of vessel 219026257 in chapter 2, pymeosais1_a/b
(fig_pymeosais1.py) and pymeosais2_a (pymeos_ais2_plot.py): one ground, one panel size and the
towns the chapter names, so that the three maps print at one scale over one extent."""
import geopandas as gpd

# The towns that the chapter names for this trajectory (OpenStreetMap place nodes), labelled in the overlay
PLACES = [('Fredericia', 55.5652680, 9.7562169, 'south'), ('Middelfart', 55.4993014, 9.7392181, 'north')]
# Each map is 0.48 of the text width wide with the shape of 527 x 422
TEXTWIDTH_MM = 332.89723 / 72.27 * 25.4
WIDTH_MM = 0.48 * TEXTWIDTH_MM
HEIGHT_MM = WIDTH_MM * 422 / 527
# The ground holds the two simplified trips of pymeosais1_a/b (written by pymeos_ais1.py) and the
# towns, with a margin of MARGIN of its size on every side
MARGIN = 0.05


def bounds(data):
    """The extent (south, west, north, east) of the three maps, from the trips in the folder data,
    in the form the argument bounds of #print_map of vgprint.py takes. The computation is the one
    fig_pymeosais1.py made inline; no other figure script shares an extent, so there is no sibling."""
    ext = gpd.GeoSeries(list(gpd.points_from_xy([p[2] for p in PLACES], [p[1] for p in PLACES]))
                        + [gpd.read_file(f'{data}/{n}.gpkg').to_crs(4326).union_all()
                           for n in ('pymeosais1_a', 'pymeosais1_b')]).total_bounds
    dx, dy = MARGIN * (ext[2] - ext[0]), MARGIN * (ext[3] - ext[1])
    return (ext[1] - dy, ext[0] - dx, ext[3] + dy, ext[2] + dx)
