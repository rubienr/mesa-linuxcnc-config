# Probing, pendant, and operator controls

## Automatic relative tool-length offset

The legacy setup used `M600` to make the next tool the job reference. Its
remapped `M6` stopped spindle/coolant, raised Z, moved to the fixed sensor,
performed coarse and fine `G38.2` probes, calculated a relative length, applied
`G43.1`, and returned to the corrected prior position.

Recovered values are **Legacy-derived**:

| Item | Value |
| --- | ---: |
| Coarse sensor X/Y | X 62 mm, Y 489 mm |
| Fine sensor X/Y | X 77 mm, Y 489 mm |
| Safe/travel Z | 0 mm |
| Fast approach / lowest probe Z | −55 mm / −129 mm |
| Retract | 1 mm |
| Coarse / fine feed | 180 / 10 mm/min |
| Manual tool-change X/Y | X 120 mm, Y 50 mm |

Revalidate every coordinate. Wrong sensor position or polarity can drive the
tool into the table.

## Workpiece touch-off

Legacy `probe-touch-off.ngc` used `G38.2` on X, Y, or Z and updated the active
work coordinate system with `G10 L2`. Pendant commands used a 10 mm maximum
move at 15 mm/min, 10.00 mm X/Y plate thickness, and 26.40 mm Z thickness.
Verify the physical plate dimensions before reuse.

The fixed sensor and removable probe both fed `motion.probe-input`; current
wiring and HAL must make selection, combination, and fault behavior explicit.

## Wireless pendant

The installed label reads `MACH3`, `WHB04B-6`, `QC01`, `2017-05`, correcting
an earlier `WHB08B-4:4` transcription. The receiver identifies as
`10ce:eb93`, manufacturer `KTURT.LTD`, matching LinuxCNC's
`xhc-whb04b-6` component.

A standalone live probe could not open the receiver because the desktop user
lacked USB/hidraw write access and no matching udev rule was installed. Identity
is confirmed; live buttons, selectors, and wheel reports remain to be tested.
The upstream protocol notes also retain checksum/CRC uncertainty for some
button packets; basic pendant support still exists.

The commissioning profile supplies a least-privilege `uaccess` rule at
[`../../config/frida-mesa/udev/70-xhc-whb04b-6.rules`](../../config/frida-mesa/udev/70-xhc-whb04b-6.rules).

## Front-panel switches

| Switch | Stated function | Details still needed |
| --- | --- | --- |
| Monitor | Monitor power | Voltage, fuse, mains versus low-voltage switching |
| Vacuum relay | 230 V vacuum relay | Relay/contactor, coil, contacts, controlled load |
| Auxiliary power | 5 V/12 V peripherals | Supply, rail currents, fusing, consumers |
| Spindle power | VFD/spindle power | Direct mains switch versus contactor; interlocks |
| Stepper-driver power | Drive supply | Switching, discharge time, current `U1` behavior |
| Vacuum pump | Vacuum pump | Model, voltage/current, distinction from vacuum relay |

Future schematics must show these manual controls even when LinuxCNC does not
monitor them.
