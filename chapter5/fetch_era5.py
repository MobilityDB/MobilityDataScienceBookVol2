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

"""Download the 10 m wind components of ERA5 hourly data on single levels for
one day over the waters of the chapter, from the Copernicus Climate Data Store.

    python3 fetch_era5.py <YYYYMMDD> <output.nc>

Needs the package cdsapi, an API key in ~/.cdsapirc, and the terms of the
dataset accepted on its page of the Climate Data Store. Licence CC-BY-4.0.
"""
import sys

import cdsapi

day, out = sys.argv[1], sys.argv[2]
request = {
    "product_type": ["reanalysis"],
    "variable": ["10m_u_component_of_wind", "10m_v_component_of_wind"],
    "year": [day[0:4]],
    "month": [day[4:6]],
    "day": [day[6:8]],
    "time": [f"{h:02d}:00" for h in range(24)],
    "area": [58.5, 3, 53.5, 16.5],
    "data_format": "netcdf",
    "download_format": "unarchived",
}
cdsapi.Client().retrieve("reanalysis-era5-single-levels", request, out)
print("wrote", out)
