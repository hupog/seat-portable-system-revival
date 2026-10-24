# 1. Diagnosis

## Starting point

- Unit: SEAT Portable System (Garmin hardware, Windows CE 6.0),
  bootloader/OS 2.10, Bluetooth firmware H14423-V2R31.
- Software: NAVIGON MobileNavigator 7.13.9 (build 5234), SEAT menu shell
  `VwUserShell` 8.0.0, phone app `PhoneApplication` 7.13.9.
- Symptom: shows the SEAT logo, then restarts after anywhere between 15 s and
  3 min. Never reaches the map. Once, a week earlier, it booted fine.

Over USB the unit exposes its internal flash ("My Flash Disk", ~3.7 GB) as a
drive. That drive was mounted in WSL with `mount -t drvfs`, and all the work
below was done on it.

## Step 1: what the device already logged

`ErrorReporter.exe` is registered as the Windows CE JIT debugger and writes a
stack trace for every crash or freeze into `NAVIGON\ErrorReporter\`
(`MaxNumberOfStacktraceFiles=100`, `ResetAfterException=1`).

| Program | Reports | Type |
|---|---|---|
| `navigon.exe` | 79 + 1 | Exception `0xC0000005` (access violation), **always at `0x00BADAB8`** |
| `PhoneApplication.exe` | 18 | Freeze: `ResyLightBtMainLoop` timeout |
| `MediaPlayer.exe` | 2 | Freeze |

Parsing the PE headers of `navigon.exe` shows `.text` spans
`0x00011000–0x00C4BF54`, so `0x00BADAB8` is an **instruction in the program's
own code**, not a fixed physical memory location. The stack showed two functions
calling each other repeatedly, which typically means walking a data structure
with a bad value in it.

Every report triggers a full device reset (`ResetAfterException=1`), and every
freeze triggers a watchdog reset (`ActionAtTimeout = 1`). That explains the loop.

## Step 2: ruling out software and data

| Hypothesis | Test | Result |
|---|---|---|
| Corrupted program files | Verified all 686 non-map files against the factory `content.md5` | All OK (only `version.xml` and `device.xml` differ, as expected after activation) |
| Corrupted maps | Verified all 45 `.map` files (2.9 GB) | All OK |
| Corrupted user settings | Wiped the hidden `MN Settings` partition using the boot script's own marker-file mechanism (`CopyMNSettings.txt` + `CleanMNSettings.txt`) | Same crash |
| Corrupted runtime data | Moved `NAVIGON\Dat\*` (files not covered by the checksums) away | Same crash |
| Out of storage | Flash was 95 % full, but factory content alone fills it; less than 1 MB was added by use | Not a change: the unit always ran like this |
| Out of RAM | Each crash report records free memory | 145–152 MB free at every crash |
| Car or cradle | Booted on a wall charger | Same loop |

### A trap in the logs

The device clock had reset to **2012-01-01** on every boot. The error reporter
keeps only 100 files and deletes the "oldest" **by file name**, so each new
`..._2012...` report deleted the previous one. Only the last crash of each test
survived. That made one test look like a fix. Moving the old reports out
of the folder solved it.

## Step 3: instrumenting the device

The boot script is plain MortScript (`autorunce.mscr`). Copies of the tiny
`autorunce.exe` launcher, renamed (`diag.exe`, `diagbat.exe`, ...), run the
`.mscr` file with the same name. Each diagnostic therefore runs as a **separate
process** and cannot break the boot if it fails. See
[`../scripts/diagnostics`](../scripts/diagnostics).

Findings:

- The hidden partitions (`\MN Settings`, `\Windows`) and the registry looked normal.
- Windows CE's own event log showed only normal start-up messages.
- Two different programs (the navigator and the phone app) failed at irregular
  times; one boot survived over a minute. **Not deterministic**, so not a
  simple corrupted file.

## Step 4: the battery

Two clues pointed to power:

1. The clock resetting to 2012 and only advancing while powered means the
   battery that keeps it running was empty.
2. Files written a week earlier still had correct dates, which matched the one
   good boot.

The battery logger (`diagbat.mscr`, sampling every 2 s) settled it:

| Boot | Battery start → at reboot | External power | What stopped it |
|---|---|---|---|
| 1 | 81 % → 79 % | yes | `navigon.exe` at `0x00BADAB8` |
| 2 | 78 % → 76 % | yes | phone app freeze |
| 3 | 75 % → 73 % | yes | phone app freeze |
| 4 | 71 % → 70 % | yes | `navigon.exe` at `0x00BADAB8` |
| 5 (unplugged) | **6 %** | no | — |

The battery **drains while plugged in**. Boot is the power peak (CPU at full
load, a 15 MB navigator plus maps, GPS, Bluetooth, backlight), and the
charger plus a worn battery cannot cover it. Each voltage dip makes some process
misbehave, the watchdog reboots, and the most expensive phase starts again.
The reading jumps to its real value (6 %) once external power is removed.

In hindsight, an earlier burst of identical crashes in the logs lasted more than
four hours on a summer afternoon. Heat is hard on an old lithium cell.

**Permanent fix:** replace the internal battery (Garmin 361-00056-xx family;
check the exact part number printed on the cell).
**Temporary fix:** reduce the boot power peak. See [02-boot-sequence.md](02-boot-sequence.md).

## Lessons learned

- **Read the logs the system already writes** before guessing. Grouping them
  gave the first real lead in minutes.
- **Validate every "fixed".** The AI's first conclusion was wrong. Only a
  repeatable test with full logs separates a fix from luck.
- **Know your instrument.** Log rotation by file name plus a reset clock hid
  most of the evidence.
- **Make the device tell you more.** If a system can run scripts at boot, it can
  also run diagnostics.
- **Software symptoms can have hardware causes.** Two unrelated programs
  failing at random times is a strong hint.
- **Every change reversible.** A verified full backup, then one change at a time,
  each with its own backup.
