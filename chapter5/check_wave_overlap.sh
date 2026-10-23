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

# Compare the significant wave height of the Baltic Sea and North West Shelf
# products at 12:00 on January 20, 2026, where both have a value on the 1 km
# grid of prep_waves.sh: the number of cells, the mean of the differences, the
# mean absolute difference, and its 95th percentile. Reads the files fetched by
# `fetch_data.sh cmems` and warps each product exactly as prep_waves.sh does.
set -e
SRC=${DATA:-$PWD/data}/cmems
W=$SRC/work
mkdir -p $W
cd $W
gdal_translate -q -b 13 -unscale -ot Float32 -a_nodata -9999 -a_srs EPSG:4326 \
  'NETCDF:"../nws_wav_20260120.nc":VHM0' nws_12.tif
gdal_translate -q -b 13 -ot Float32 -a_srs EPSG:4326 \
  'NETCDF:"../bal_wav_20260120.nc":VHM0' bal_12.tif
for p in nws bal; do
  gdalwarp -q -overwrite -t_srs EPSG:25832 -tr 1000 1000 -tap \
    -te_srs EPSG:4326 -te 3 53.5 16.5 58.5 -r near -dstnodata -9999 \
    ${p}_12.tif ${p}_12_25832.tif
done
python3 - <<'EOF'
import numpy as np
from osgeo import gdal
n = gdal.Open('nws_12_25832.tif').ReadAsArray().astype(float)
b = gdal.Open('bal_12_25832.tif').ReadAsArray().astype(float)
both = (n != -9999) & (b != -9999) & np.isfinite(n) & np.isfinite(b)
d = n[both] - b[both]
print('cells', int(both.sum()), 'mean', round(d.mean(), 3),
      'mad', round(np.abs(d).mean(), 3), 'p95', round(np.percentile(np.abs(d), 95), 3))
EOF
rm -f nws_12.tif bal_12.tif nws_12_25832.tif bal_12_25832.tif
