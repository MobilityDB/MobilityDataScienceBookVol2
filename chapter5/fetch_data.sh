#!/bin/bash
# Put every dataset of the chapter into the directory $DATA (default: data/
# below the working directory), with no account needed. The AIS day, the depth
# model, the ports, and the protected areas come from their publishers; the
# subsets of the Copernicus Marine Service and of ERA5 come from datasets/ of
# this repository, as their licences allow.
#
#   bash fetch_data.sh [ais] [ddm] [aux] [cmems] [era5]
#
# Without arguments, all of them are fetched. FROM_PUBLISHER=1 downloads cmems
# and era5 again from their publishers instead: cmems then needs the Copernicus
# Marine Toolbox and a free account (copernicusmarine login), and era5 needs
# cdsapi, an API key in ~/.cdsapirc, and the terms of the ERA5 dataset accepted
# on its page.
# The helpers fetch and sub follow #field of prep_fields.sh: one shell function
# per repeated step, the loop in the caller. The book repository has no other
# download script.
set -e
DATA=${DATA:-$PWD/data}
HERE=$(cd "$(dirname "$0")" && pwd)
PARTS=${*:-ais ddm aux cmems era5}
mkdir -p "$DATA"

fetch() { # url file
  if [ -s "$2" ]; then echo "present: $2"; else
    echo "fetching: $2"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; fi
}

for part in $PARTS; do
  case $part in
  ais)
    # One day of AIS of the Danish Maritime Authority.
    mkdir -p "$DATA/ais"
    fetch http://aisdata.ais.dk/aisdk-2026-01-20.zip "$DATA/ais/aisdk-2026-01-20.zip"
    ;;
  ddm)
    # Denmark's Depth Model, 50 m, from the Danish Geodata Agency (the INSPIRE
    # download service of the model), with its readme.
    mkdir -p "$DATA/ddm"
    W='https://ftp.sdfe.dk/main.html?download&weblink=b4324b6389898704fd8ec7484882dbf3&subfolder=2024&realfilename='
    fetch "${W}ddm%5F50m%2Edybde%2Etiff" "$DATA/ddm/ddm_50m.dybde.tiff"
    fetch "${W}ddm%5F50m%2Ereadme%2Epdf" "$DATA/ddm/ddm_50m.readme.pdf"
    ;;
  aux)
    # Ports: GISCO ports 2013 of Eurostat. Protected areas: the World Database on
    # Protected Areas of Denmark from Protected Planet, in its current monthly
    # release (WDPA_RELEASE, e.g. Sep2026, defaults to the current month).
    # build_aux_data.sh turns both into data/port.csv and data/natural_areas.csv.gz.
    mkdir -p "$DATA/aux"
    fetch https://ec.europa.eu/eurostat/cache/GISCO/geodatafiles/PORT_2013_SH.zip \
      "$DATA/aux/PORT_2013_SH.zip"
    # A release is published as shapefiles (..._DNK_shp.zip) or as a file
    # geodatabase (..._DNK.zip); the first name served is kept.
    R=${WDPA_RELEASE:-$(LC_ALL=C date +%b%Y)}
    U=https://d1gam3xoknrgr2.cloudfront.net/current/WDPA_WDOECM_${R}_Public_DNK
    if [ -s "$DATA/aux/WDPA_${R}_DNK_shp.zip" ] || [ -s "$DATA/aux/WDPA_${R}_DNK_gdb.zip" ]; then
      echo "present: WDPA $R"
    elif curl -fsI "${U}_shp.zip" > /dev/null; then
      fetch "${U}_shp.zip" "$DATA/aux/WDPA_${R}_DNK_shp.zip"
    else
      fetch "${U}.zip" "$DATA/aux/WDPA_${R}_DNK_gdb.zip"
    fi
    ;;
  cmems)
    # Hourly products of the Copernicus Marine Service for January 20, 2026. The
    # subsets are in datasets/cmems of this repository, which the licence of the
    # service allows; FROM_PUBLISHER=1 downloads them again from the service.
    # sub mirrors #fetch: skip a present file, else copy or download it.
    mkdir -p "$DATA/cmems"
    B="-x 3 -X 16.5 -y 53.5 -Y 58.5 -t 2026-01-20T00:00:00 -T 2026-01-21T00:00:00 -o $DATA/cmems"
    sub() { # dataset file variables...
      local ds=$1 f=$2; shift 2
      if [ -s "$DATA/cmems/$f" ]; then echo "present: $DATA/cmems/$f"
      elif [ -z "$FROM_PUBLISHER" ]; then cp "$HERE/datasets/cmems/$f" "$DATA/cmems/$f"
      else copernicusmarine subset -i "$ds" "$@" $B -f "$f"; fi
    }
    sub cmems_mod_bal_phy_anfc_PT1H-i bal_phy_20260120.nc -v thetao -v so -v sla -v mlotst \
      --minimum-depth 0 --maximum-depth 1
    sub cmems_mod_bal_wav_anfc_PT1H-i bal_wav_20260120.nc -v VHM0 -v VMDR
    sub cmems_mod_nws_phy-sst_anfc_1.5km-2D_PT1H-i nws_sst_20260120.nc -v thetao
    sub cmems_mod_nws_phy-sss_anfc_1.5km-2D_PT1H-i nws_sss_20260120.nc -v so
    sub cmems_mod_nws_wav_anfc_1.5km_PT1H-i nws_wav_20260120.nc -v VHM0 -v VMDR
    ;;
  era5)
    # 10 m wind of ERA5 for the day of the chapter, in datasets/era5 of this
    # repository (CC-BY-4.0); FROM_PUBLISHER=1 downloads it again from the
    # Climate Data Store.
    mkdir -p "$DATA/era5"
    for d in 20260120; do
      f=era5_wind10m_$d.nc
      if [ -s "$DATA/era5/$f" ]; then echo "present: era5 $d"
      elif [ -z "$FROM_PUBLISHER" ]; then cp "$HERE/datasets/era5/$f" "$DATA/era5/$f"
      else python3 "$HERE/fetch_era5.py" "$d" "$DATA/era5/$f"; fi
    done
    ;;
  *) echo "unknown part: $part"; exit 1 ;;
  esac
done
