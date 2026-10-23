#!/bin/bash
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

# Section 8: significant wave height (VHM0) of January 20, 2026, from the
# Copernicus Marine hourly wave products of the Baltic Sea and the North West
# Shelf, merged and reprojected ONCE to EPSG:25832 on a 1 km grid, one GeoTIFF
# per hourly step. The Baltic value is kept where the Baltic model has one, and
# the North West Shelf value elsewhere (gdalwarp writes the later source over
# the earlier one where the later one has data). Nearest-neighbour resampling
# keeps the model values.
set -e
SRC=${DATA:-$PWD/data}/cmems
OUT=$SRC/waves25832
mkdir -p $OUT $SRC/work
cd $SRC/work
for b in $(seq 1 24); do
  h=$(printf '%02d' $((b - 1)))
  gdal_translate -q -b $b -unscale -ot Float32 -a_nodata -9999 -a_srs EPSG:4326 \
    'NETCDF:"../nws_wav_20260120.nc":VHM0' nws_$h.tif
  gdal_translate -q -b $b -ot Float32 -a_srs EPSG:4326 \
    'NETCDF:"../bal_wav_20260120.nc":VHM0' bal_$h.tif
  gdalwarp -q -overwrite -t_srs EPSG:25832 -tr 1000 1000 -tap \
    -te_srs EPSG:4326 -te 3 53.5 16.5 58.5 -r near -dstnodata -9999 \
    -co COMPRESS=DEFLATE nws_$h.tif bal_$h.tif $OUT/vhm0_20260120T${h}.tif
  rm -f nws_$h.tif bal_$h.tif
done
ls $OUT | wc -l
gdalinfo -stats $OUT/vhm0_20260120T12.tif | grep -E 'Size is|Minimum='
