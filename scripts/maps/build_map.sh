#!/usr/bin/env bash
# Builds a lightweight Navit map (binfile) from OpenStreetMap data.
#
# Requirements (Debian/Ubuntu/WSL):  sudo apt install osmium-tool maptool curl
# Usage:                             ./build_map.sh [output.bin]
#
# Region: Galicia extract from Geofabrik, cropped to the Vigo area
# (Vigo, O Porrino, Redondela, Pontevedra, Tui, Baiona). Change BBOX to taste.
# Only what is needed to display streets and calculate routes is kept:
# roads and their names, places, water and administrative boundaries.
# Buildings and POIs are dropped - they are what makes rendering slow on a
# ~2013 Windows CE device. Result: ~7 MB instead of ~95 MB for all of Galicia.
set -euo pipefail

OUT="${1:-vigo_area.bin}"
SRC_URL="https://download.geofabrik.de/europe/spain/galicia-latest.osm.pbf"
BBOX="-8.95,41.95,-8.35,42.50"   # min_lon,min_lat,max_lon,max_lat
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading $SRC_URL ..."
curl -fsSL -o "$WORK/region.osm.pbf" "$SRC_URL"
curl -fsSL -o "$WORK/region.osm.pbf.md5" "$SRC_URL.md5"
(cd "$WORK" && sed 's/galicia-latest.osm.pbf/region.osm.pbf/' region.osm.pbf.md5 | md5sum -c -)

echo "Cropping to $BBOX ..."
osmium extract --overwrite -b "$BBOX" "$WORK/region.osm.pbf" -o "$WORK/area.osm.pbf"

echo "Keeping roads, places, water and boundaries only ..."
osmium tags-filter --overwrite "$WORK/area.osm.pbf" \
  w/highway nwr/place \
  w/natural=water,coastline w/waterway=river,riverbank r/natural=water \
  r/boundary=administrative \
  -o "$WORK/light.osm.pbf"

echo "Converting to Navit binfile ..."
maptool --protobuf -i "$WORK/light.osm.pbf" "$OUT" > "$WORK/maptool.log" 2>&1

ls -lh "$OUT"
echo "Copy it to \\My Flash Disk\\Navit\\maps\\ on the device."
