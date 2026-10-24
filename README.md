# SEAT Portable System revival

Bringing a 2013 in-car navigation unit back to life, more than five years after
official support ended, using an AI coding assistant as a diagnostic partner.

The device is the **SEAT Portable System** used in the SEAT Ibiza 6J (2012–2015):
a Garmin-built unit running **Windows CE 6.0** with NAVIGON MobileNavigator 7.13.9,
a SEAT-branded menu shell, a Bluetooth phone app and a media player. Updates
ended in November 2020: no firmware downloads, no maps, no public technical documentation.

It was stuck in a **reboot loop**: SEAT logo, then a restart every 15 s to 3 min.

## TL;DR

| | |
|---|---|
| **Symptom** | Endless reboots, never reached the map. Same on car power and on a wall charger. |
| **What the logs said** | 79 of 100 crash reports were the *same* access violation in `navigon.exe`; the rest were Bluetooth app freezes. A watchdog rebooted the whole unit after each one. |
| **Real root cause** | A worn-out internal battery. It drained *while plugged in* and read 6 % once unplugged. The crashes were symptoms of voltage drops during the boot power peak. |
| **Workaround** | A "soft boot": staggered start-up, the heavy navigator removed from boot, and watchdogs that restart only the failing program instead of the whole device. |
| **Navigation** | The abandoned navigator was replaced by [Navit](https://github.com/navit-gps/navit) (open source) with a lightweight 2026 OpenStreetMap map. It only loads when the menu's Navigation button is pressed. |
| **Status** | Boots reliably, phone/media/menu work. Navit shows the map; routing and GPS are still being tuned. Replacing the battery is the permanent fix. |

## How the AI helped

This was done in a terminal session with Claude Code (an AI coding assistant)
working directly on the device's flash drive (mounted in WSL). Nobody involved
knew this system beforehand. The useful parts were:

- **Reading what the system already recorded.** The device kept 100 crash dumps.
  Grouping them by program, error code and address showed one fault repeating
  at the same instruction (`0x00BADAB8`, inside `navigon.exe`'s code section).
- **Reconstructing an undocumented system.** The boot script
  (`autorunce.mscr`, MortScript), six watchdog configs, the error reporter and the
  inter-app config (`NgAppCom.xml`) together revealed how the unit boots, who
  supervises whom and what triggers a reboot.
- **Instrumenting the device with its own tools.** The boot script interpreter
  was used to add diagnostics that capture what USB cannot reach: the hidden
  settings partition, the Windows CE registry and event logs, and the battery
  level every 2 seconds. See [`scripts/diagnostics`](scripts/diagnostics).
- **Ruling things out with evidence.** Checksums of all 744 factory files
  (`content.md5`), RAM and storage figures, wiped settings, a wall-charger test.
  Each hypothesis was tested before moving on.
- **Being wrong, and catching it.** At one point the assistant declared the
  navigator crash fixed. The next test showed it was not, and the analysis was
  corrected. A dead end in the crash-log rotation (new logs silently deleting
  each other because the device clock had reset to 2012) was also caught this way.

Lessons learned are at the end of [`docs/01-diagnosis.md`](docs/01-diagnosis.md).

## Repository layout

```
docs/
  01-diagnosis.md       how the root cause was found (logs, tests, battery data)
  02-boot-sequence.md   how the unit boots, and the "soft boot" workaround
  03-navit.md           replacing the navigator with Navit + OpenStreetMap
scripts/
  diagnostics/          MortScript diagnostics run at boot (snapshot, registry, battery)
  navigation/           Navigation-button targets (launch Navit / do nothing)
  maps/build_map.sh     builds the lightweight OSM map with osmium + maptool
changes/                unified diffs of every configuration file that was modified
```

## What is *not* here

- No Garmin/NAVIGON binaries, maps or full configuration files (copyrighted).
  Only our own scripts and diffs of the lines that were changed.
- No device identifiers, activation codes, vehicle data or personal data.

## Safety notes if you try this on your own unit

1. **Back up the whole drive first** and verify the copy. Every change here is a
   text edit that can be reverted by copying the original file back.
2. Change one thing at a time and test.
3. Do **not** try to reflash the OS with a weak battery: losing power mid-flash
   can brick the unit.
4. If your unit reboots only while plugged in, check the battery first.

## License

The scripts and documentation in this repository are released under the
[MIT License](LICENSE). Navit is GPL-licensed and OpenStreetMap data is
© OpenStreetMap contributors (ODbL). SEAT, Garmin and NAVIGON are trademarks
of their respective owners; this project is not affiliated with them.
