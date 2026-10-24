# 3. Replacing the navigator with Navit

The original maps date from 2012 and official updates ended in 2020. The
legal route to current maps on this hardware is open source:
**[Navit](https://github.com/navit-gps/navit)** (it has Windows CE builds)
and **OpenStreetMap** data, updated daily and free to use under the ODbL.

## Install

1. Download `navit-wince-v0.5.7.zip` from the
   [Navit releases](https://github.com/navit-gps/navit/releases/tag/v0.5.7)
   and extract it to `\My Flash Disk\Navit\` (~16 MB).
2. Build a map with [`../scripts/maps/build_map.sh`](../scripts/maps/build_map.sh)
   and copy it to `\My Flash Disk\Navit\maps\`.
3. Apply the `navit.xml` changes in [`../changes/navit.xml.diff`](../changes/navit.xml.diff).
4. Copy the launcher stub `autorunce.exe` to `abrenav.exe`, add
   [`abrenav.mscr`](../scripts/navigation/abrenav.mscr) next to it, and point the
   `MobileNavigator` `<Exe>` in every `NgAppCom.xml` to `.\..\abrenav.exe`.

## Problems found and fixes

### White screen with only zoom buttons

`navit.log` (written next to `navit.exe`) showed:

```
map_binfile_open: Failed to load '$NAVIT_SHAREDIR/maps/...bin'
xinclude: Unable to include '\My Flash Disk\Navit\$NAVIT_SHAREDIR/navit_layout_*.xml'
```

This Windows CE build does not expand `$NAVIT_SHAREDIR` / `$NAVIT_USER_DATADIR`.
Without the map and the layouts (the drawing styles) everything renders white.
The fix uses absolute or relative paths and names the layout files explicitly:

```xml
<map type="binfile" data="\My Flash Disk\Navit\maps\vigo_area.bin"/>
<xi:include href="navit_layout_car.xml"/>
<xi:include href="navit_layout_car_dark.xml"/>
```

### Slow rendering

- **Lighter map.** All of Galicia converted with `maptool` is ~95 MB. Cropping to
  the Vigo area and keeping only roads, places, water and boundaries brings it
  down to **~7 MB**. Buildings and POIs are what cost the most to draw.
- **No automatic 3D tilt.** The default config tilts the map when following the
  vehicle (`pitch=20`); it is forced to `pitch=0`.

### Small buttons on a 480×272 touch screen

On-map buttons were enlarged from 24 to 48 px. The menu was set to
`font_size="300" icon_s="48" icon_l="64"`.

### Start position

`center="lon lat"` sets where the map opens before the GPS has a fix. Navit
also saves the last position to `data\center.txt`, which **overrides** the config.
Delete that file after changing `center`.

## GPS

The original navigator's `Settings\Core\CoreConfig.ini` declares the internal
receiver as `Port=7`, `BaudRate=38400`, so Navit uses:

```xml
<vehicle ... source="wince:COM7:" baudrate="38400">
```

Status: not yet confirmed with an outdoor fix.

## Using it

- Tap the map to open Navit's menu (it is Navit's own UI, not SEAT's).
- **Actions → Town** → pick the town → **Street** → pick the street →
  **Set as destination**.
- **Quit** closes Navit and returns to the SEAT menu.
