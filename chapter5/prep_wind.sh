#!/bin/bash
# Section 8: the 10 m wind speed sqrt(u10^2 + v10^2) of ERA5 for one day, one
# GeoTIFF per hourly step, reprojected ONCE to EPSG:25832 on a 5 km grid with
# nearest-neighbour resampling. Usage: prep_wind.sh <YYYYMMDD>, reading
# era5/era5_wind10m_<YYYYMMDD>.nc and writing era5/wind25832_<YYYYMMDD>/.
set -e
D=$1
ER=${DATA:-$PWD/data}/era5
OUT=$ER/wind25832_$D
mkdir -p $OUT
cd $ER
for b in $(seq 1 24); do
  h=$(printf '%02d' $((b - 1)))
  gdal_calc.py --quiet --overwrite --type=Float32 \
    -A "NETCDF:\"era5_wind10m_$D.nc\":u10" --A_band=$b \
    -B "NETCDF:\"era5_wind10m_$D.nc\":v10" --B_band=$b \
    --calc='sqrt(A*A+B*B)' --outfile=wind_${D}_${h}.tif
  gdalwarp -q -overwrite -s_srs EPSG:4326 -t_srs EPSG:25832 -tr 5000 5000 -tap \
    -te_srs EPSG:4326 -te 3 53.5 16.5 58.5 -r near -dstnodata -9999 \
    -co COMPRESS=DEFLATE wind_${D}_${h}.tif $OUT/wind_${D}T${h}.tif
  rm -f wind_${D}_${h}.tif
done
echo "$(ls $OUT | wc -l) files"
gdalinfo -stats $OUT/wind_${D}T10.tif | grep -E 'Minimum='
