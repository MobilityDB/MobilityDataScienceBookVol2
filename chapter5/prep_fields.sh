#!/bin/bash
# Section 8: sea surface temperature and salinity of January 20, 2026, from the
# Copernicus Marine hourly physics products of the Baltic Sea and the North West
# Shelf, merged as the wave height (the Baltic value where the Baltic model has
# one) and reprojected ONCE to EPSG:25832 on a 1 km grid; and the 10 m wind speed
# sqrt(u10^2 + v10^2) of ERA5, reprojected to EPSG:25832 on a 5 km grid. One
# GeoTIFF per hourly step, nearest-neighbour resampling.
set -e
CM=${DATA:-$PWD/data}/cmems
ER=${DATA:-$PWD/data}/era5
mkdir -p $CM/work $CM/sst25832 $CM/sss25832 $ER/wind25832
cd $CM/work
field() { # name nwsfile nwsvar balvar
  for b in $(seq 1 24); do
    h=$(printf '%02d' $((b - 1)))
    gdal_translate -q -b $b -unscale -ot Float32 -a_nodata -9999 -a_srs EPSG:4326 \
      "NETCDF:\"../$2\":$3" nws_$h.tif
    gdal_translate -q -b $b -ot Float32 -a_srs EPSG:4326 \
      "NETCDF:\"../bal_phy_20260120.nc\":$4" bal_$h.tif
    gdalwarp -q -overwrite -t_srs EPSG:25832 -tr 1000 1000 -tap \
      -te_srs EPSG:4326 -te 3 53.5 16.5 58.5 -r near -dstnodata -9999 \
      -co COMPRESS=DEFLATE nws_$h.tif bal_$h.tif $CM/${1}25832/${1}_20260120T${h}.tif
    rm -f nws_$h.tif bal_$h.tif
  done
}
field sst nws_sst_20260120.nc thetao thetao
field sss nws_sss_20260120.nc so so
cd $ER
for b in $(seq 1 24); do
  h=$(printf '%02d' $((b - 1)))
  gdal_calc.py --quiet --overwrite --type=Float32 \
    -A 'NETCDF:"era5_wind10m_20260120.nc":u10' --A_band=$b \
    -B 'NETCDF:"era5_wind10m_20260120.nc":v10' --B_band=$b \
    --calc='sqrt(A*A+B*B)' --outfile=wind_$h.tif
  gdalwarp -q -overwrite -s_srs EPSG:4326 -t_srs EPSG:25832 -tr 5000 5000 -tap \
    -te_srs EPSG:4326 -te 3 53.5 16.5 58.5 -r near -dstnodata -9999 \
    -co COMPRESS=DEFLATE wind_$h.tif wind25832/wind_20260120T${h}.tif
  rm -f wind_$h.tif
done
for d in $CM/sst25832 $CM/sss25832 $ER/wind25832; do
  echo "$(basename $d): $(ls $d | wc -l) files"
  gdalinfo -stats $(ls $d/*T12.tif) | grep -E 'Minimum='
done
