# Motion, homing, limits, and sensors

All values recovered from the old configuration are **Legacy-derived** until
commissioning proves them on the current machine.

## Stepper-drive settings recovered from legacy notes

| Setting | X | Y | Z |
| --- | ---: | ---: | ---: |
| Peak current | 3.3 A | 3.3 A | 3.5 A |
| Idle current / timeout | 50% / 2,000 ms | 50% / 2,000 ms | 50% / 2,000 ms |
| Electrical damping | 1,000 | 1,000 | 1,000 |
| Alarm polarity | Active low | Active low | Active low |
| Active step edge / direction definition | Rising / Low | Rising / Low | Rising / Low |
| Phase-error / sensorless-stall detection | Enabled | Enabled | Enabled |
| Pulse smoother | Disabled | Disabled | Disabled |
| ENA reset / high-active ENA | Enabled | Enabled | Enabled |

Legacy notes say pulse smoothing caused sporadic lost steps. They also record a
move from a 24 V toroidal supply to HWS1000-48, which reduced resonance; that
supply was later replaced by the installed fanless 56 VDC `U1`.

## Machine coordinate envelope and homing

These are old software limits, not verified mechanical measurements.

| Axis | Minimum | Maximum | Span | Home | Offset | Sensor/direction | Max velocity | Max acceleration |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| X | 61 mm | 571 mm | 510 mm | 62 mm | 60 mm | X−, negative | 35 mm/s | 85 mm/s² |
| Y | 14 mm | 491 mm | 477 mm | 490 mm | 492 mm | Y+, positive | 35 mm/s | 85 mm/s² |
| Z | −130 mm | 0.5 mm | 130.5 mm | 0 mm | 1 mm | Z+, positive/up | 35 mm/s | 85 mm/s² |

Legacy scale is 80 steps/mm for X/Y and −80 steps/mm for Z. Z homes first
(`HOME_SEQUENCE=0`), followed by X and Y together (`HOME_SEQUENCE=1`).
Re-establish direction, scale, usable travel, and braking distance before using
these limits.

```text
                         Y+ / home near 490 / limit 491
                         ^
 X- / home near 62       +------------------------------> X+
 X limit 61                    510 mm span                  X limit 571

 Z+ / home 0 / upper limit 0.5
 ^
 | 130.5 mm span
 v
 Z- / lower limit -130
```

## Limit and home sensors

| Number | Label | Confirmed position/function |
| ---: | --- | --- |
| 4 | `X-` | X minimum |
| 5 | `XH` | Dedicated X home |
| 6 | `X+` | X maximum |
| 3 | `Y+` | Y maximum |
| Not recorded | `YH` | Dedicated Y home |
| Not recorded | `Y-` | Y minimum |
| 8 | `Z-` | Z minimum |
| 7 | `Z+` | Z maximum |

There is no separate Z-home sensor. The active legacy HAL ignored `XH` and
`YH`, using X−, Y+, and Z+ as home signals. Test positions, polarity, and the
desired sequence before using dedicated X/Y home sensors; decide explicitly
whether Z+ remains both home and upper limit.

## Sensor interface migration

The old Panther interface needed a level-protection workaround because the NPN
sensors required more voltage than the BeagleBone input tolerated. Do not copy
that circuit merely because it appears in the legacy schematic.

The 7I95T isolated inputs accept 4–36 VDC and positive or negative commons for
sourcing or sinking applications. Design and test the exact common, polarity,
sensor supply, fuse, shielding, and allocation before connection.
