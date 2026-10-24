# 2. Boot sequence and the "soft boot"

## How the unit boots

At start-up Windows CE runs `\My Flash Disk\autorunce.exe`, a MortScript
launcher stub, which executes `autorunce.mscr`. The original script:

1. Handles marker files (`CopyMNSettings.txt` backs up the hidden settings
   partition, `CleanMNSettings.txt` wipes it).
2. Writes the Bluetooth address, starts the car communication process
   (`VwCommunicationExe`) and brands the device.
3. Starts **everything else at once** through `WatchdogPuppy.exe`: navigator,
   Bluetooth core, SEAT menu (`VwUserShell`), phone app, media player and the
   hardware watchdog.

### Who reboots the unit

| Component | Config | Original behaviour |
|---|---|---|
| Error reporter | `ErrorReporter.ini` | `ResetAfterException=1`: any crash → device reset |
| Per-app watchdogs | `Watchdog_MN/PhoneApplication/MMP/VwUserShell.ini` | `ActionAtTimeout = 1`, `ActionAtTermination = 1`: freeze or exit → device reset |
| Bluetooth core watchdog | `Watchdog_BTCore.ini` | `= 2` with `WaitTimeUntilRestart` / `MaximumRestartCounter`: restarts **only that process** |
| Hardware watchdog | `Watchdog_HW.ini` (`WolfSafety`) | Waits for "alive" events from navigator, menu, phone and player; missing event → hardware reset |

The Bluetooth core already used a gentler "restart just this program" mode.
Its config was the template for the changes below. The meaning of
`ActionAt* = 2` is **inferred** from that file, not documented.

## The workaround

All changes are in [`../changes`](../changes) as unified diffs.

### 1. Staggered start-up, Bluetooth first (`autorunce.mscr`)

| Order | Program |
|---|---|
| 0 s | Bluetooth core (right after its address is written) |
| ~0 s | Car communication, branding, volume UI, SEAT menu + hardware watchdog |
| +3 s | Phone app |
| +43 s | Media player |
| — | Original navigator: **not started at boot** |

Navigation was not needed day to day, and the navigator was by far the
heaviest process and the main crasher. Removing it from boot did most of the work.
Bluetooth was moved first so the phone pairs as soon as possible.

### 2. Restart the program, not the device

- `ErrorReporter.ini`: `ResetAfterException=0`.
- Navigator, phone, media player and menu watchdogs:
  `ActionAtTimeout/ActionAtTermination = 2`, plus `WaitTimeUntilRestart`
  (10–20 s) and `MaximumRestartCounter=10`.
- `Watchdog_HW.ini`: only the menu's alive event is supervised, with a 60 s
  timeout. A slow phone app no longer reboots the whole unit.

### 3. Lighter diagnostics

Only the battery logger stays enabled, sampling every 10 s instead of 2 s.
The heavier snapshot and registry scripts were removed from boot.

## The Navigation button

Pressing **Navigation** in the SEAT menu kept rebooting the unit even with the
navigator removed from boot. New crash reports explained it: the menu itself
launches the navigator. `NgAppCom.xml` (one identical copy per app folder)
declares each application's executable:

```xml
<Application Name="MobileNavigator">
  <Exe>.\..\NAVIGON\navigon.exe</Exe>
```

Pointing `<Exe>` elsewhere, in all six copies, changes what the button does:

- `.\..\nonav.exe` → runs [`nonav.mscr`](../scripts/navigation/nonav.mscr),
  which just brings the menu back. The button does nothing.
- `.\..\abrenav.exe` → runs [`abrenav.mscr`](../scripts/navigation/abrenav.mscr),
  which starts Navit or brings it to the front (current setup, see
  [03-navit.md](03-navit.md)).

The navigator is invisible to the device until the button is pressed.

## Language

With the navigator gone, the apps lost their shared language setting. The phone
app reads `UserSettingsLanguage.default`, so adding
`<Language>spa-ESP</Language>` fixed it. The main menu receives its
language at runtime from the navigator through the shared "Settings" group in
`NgAppCom.xml`, and no file-based setting was found, so it stays in its default
English. Known limitation.

## Results

- Boots to the SEAT menu reliably; phone, Bluetooth and media work.
- No more reboot loop, and no more resets from the Navigation button.
- The battery is still worn: this is a workaround, not a repair.
