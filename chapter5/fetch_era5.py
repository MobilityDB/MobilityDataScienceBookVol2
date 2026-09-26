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
