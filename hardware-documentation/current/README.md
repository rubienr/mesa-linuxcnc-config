# Current CNC hardware documentation

This directory is the current source of truth for the machine during migration
to LinuxCNC and a Mesa 7I95T. It separates confirmed physical evidence from
legacy-derived settings and unresolved assumptions so a task can load only the
relevant topic.

The files under
[`../legacy/beaglebone-black-panther-cape/`](../legacy/beaglebone-black-panther-cape/)
are forensic references. They must not be treated as correct for the current
machine without verification.

## Status labels

- **Confirmed**: stated by the owner or unambiguously recorded in current
  physical evidence.
- **Legacy-derived**: recovered from the old configuration or documentation;
  verify before energizing the rebuilt machine.
- **To verify**: plausible or shown in a drawing, but not confirmed physically.

## Topic index

| Topic | Read |
| --- | --- |
| Installed devices, power supplies, model identities, datasheet index | [`inventory.md`](inventory.md) |
| Motors, drives, coordinates, homing, limits, and sensor interface | [`motion.md`](motion.md) |
| Spindle, Huanyang VFD, coolant, RS-485, and register capture | [`spindle-vfd.md`](spindle-vfd.md) |
| Tool sensing, touch-off, pendant, and front-panel controls | [`controls-and-probing.md`](controls-and-probing.md) |
| Errors in the legacy schematic and the wiring-record format | [`legacy-and-wiring.md`](legacy-and-wiring.md) |
| Unresolved decisions and physical verification work | [`TODO.md`](TODO.md) |
| Generated VFD parameter table | [`huanyang-hy02d223b-register-backup.md`](huanyang-hy02d223b-register-backup.md) |

The proposed current terminal allocation is
[`../../config/frida-mesa/wiring.csv`](../../config/frida-mesa/wiring.csv).

## Safety boundary

This documentation is not an approved wiring diagram. Do not inspect,
disconnect, or measure energized mains equipment. Do not energize the spindle,
stepper drives, pump, vacuum equipment, or other mains loads from the benchmark
configuration. Verify protective earth, fusing, conductor sizes, isolation,
contact ratings, emergency-stop behavior, and every Mesa I/O voltage before
connecting field wiring.
