# Huanyang HY02D223B register backup

Captured `2026-09-19T14:10:14.449665+00:00` through `/dev/ttyUSB0` at
19,200 bit/s, 8N1, station 1.

The capture program transmitted only Huanyang function `0x01` (read
parameter). The raw, CRC-checked request and response frames are preserved in
[`data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json`](data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json).

The capture covers `PD000`–`PD250`: 170 registers returned values, 81 returned
CRC-valid unsupported replies, and none ended in errors. The complete generated
record is in the
[`Huanyang HY02D223B register table`](huanyang-hy02d223b-register-backup-table.md).

Decoded values and descriptions initially came from
[`datasheets/huanyang-hy02d223b-manual.pdf`](datasheets/huanyang-hy02d223b-manual.pdf).
That project PDF is not the same revision as the handbook delivered with this
VFD. Owner-confirmed handbook corrections, including its documented set ranges
and setting units, take precedence; untranscribed conflicts are marked pending
rather than guessed.

In the table's factory-setting column, `*` retains the manual's notation for a
model- or application-specific value; an em dash means the manual gives no
fixed initial value. A blank set range or unit means that the delivered handbook
does not document one in the transcribed material.

[1] Modified: blank means the captured value equals the numeric factory
setting; `Y` (yes) means it differs; `?` means comparison is not possible from
this capture/manual.

[2] Reserved: `R` (reserved) means explicitly marked reserved in the delivered handbook;
`N` (not present) means the parameter is not present in the project PDF; blank means it is
documented and not marked reserved.

## Important recovered settings

- Run commands and frequency both come from communications (`PD001=2`,
  `PD002=2`).
- Serial settings are station 1, 19,200 bit/s, 8N1 RTU (`PD163=1`, `PD164=2`,
  `PD165=3`).
- Base and maximum frequency are both 400 Hz (`PD004`, `PD005`).
- The lower operating limit is 13.40 Hz (`PD011`), corresponding to about
  804 rpm with `PD144=3000 rpm at 50 Hz`.
- Motor data are 220 V, 10.0 A, 2 poles and 3000 rpm at 50 Hz
  (`PD141`–`PD144`). The 10.0 A setting conflicts with the spindle's informal
  paper value of 6 A and must be resolved before commissioning.
- Reverse rotation is forbidden (`PD023=0`) and the panel STOP key is enabled
  (`PD024=1`).
- One auxiliary pump is configured (`PD130=1`), and `PD133`–`PD139` contain
  non-default pump/sleep timings and thresholds. The coolant-pump conductor
  appears to be on `FA(MB)` or `FC(MB)`; verify it physically before changing
  anything.
- No automatic abnormal restart is configured (`PD155=0`), and restart after
  instantaneous power loss is disabled (`PD153=0`).
- The delivered handbook marks `PD184`–`PD250` reserved. The VFD nevertheless
  returned `PD184=20`, `PD185=0`, `PD186=0` and `PD200=0`; preserve these values
  without assigning a meaning or writing them. Apart from `PD200`, every query
  from `PD187`–`PD250` returned a CRC-valid unsupported reply.

## Capture and rendering tools

[`tools/read-huanyang-vfd.py`](tools/read-huanyang-vfd.py) is deliberately
read-only: its request builder contains only function `0x01`. Do not replace it
with `hy_vfd --regdump` for forensic captures, because the normal `hy_vfd` loop
subsequently transmits control and frequency commands.

Regenerate the default Markdown table with:

```console
python3 hardware-documentation/current/tools/render-huanyang-register-table.py \
  hardware-documentation/current/data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json \
  hardware-documentation/current/huanyang-hy02d223b-register-backup-table.md
```

Use an output name ending in `.csv`, or pass `--format csv`, to render the same
columns and rows as CSV.
