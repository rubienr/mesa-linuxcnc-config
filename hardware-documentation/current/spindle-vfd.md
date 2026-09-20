# Spindle, Huanyang VFD, and coolant

The inverter is a Huanyang `HY02D223B`; the installed spindle is the 2.2 kW
water-cooled ER20 unit described in [`inventory.md`](inventory.md).

## Control path and coolant evidence

- Legacy `hy_vfd` used `/dev/ttyUSB0`, 19,200 baud, 8N1, address 1.
- The old UI defaulted to 800 rpm and allowed up to 24,000 rpm. This does not
  establish a safe minimum speed.
- The BerryBase adapter contains a CH340C and MAX485 ESA and is not galvanically
  isolated. Its exposed screw terminal is differential RS-485, not TTL UART.
- Mesa serial channel 0 supports two-wire low-speed RS-485, but TB4 is not one
  of the galvanically isolated field circuits and PktUART is not a
  `/dev/ttyUSB*` device. It is not a wire-for-wire or software-compatible
  replacement for the existing adapter.
- Ebyte `E810-R12` is a candidate transparent isolated RS-485 hub, not a
  confirmed purchase. `CH1` and `CH2` are duplicate branches, not RX/TX.
- The old schematic omits the coolant pump. Physical observation places it on
  `FA(MB)` or, less likely, `FC(MB)`; verify the terminal.
- Available terminal documents conflict: one table names `FA(MB)`, `FB(MA)`,
  `FC(MA)`, while a diagram orders `FC(MA)`, `FA(MB)`, `FB(MA)`. They likely
  describe one changeover multifunction relay, but continuity and labels must
  confirm that inference.
- The capture has `PD130=1` and non-default pump/sleep settings in
  `PD133`–`PD139`, while `PD050`–`PD053` do not select auxiliary-pump function
  25. Trace how the pump is actually switched.
- Verify contact type and rating; use a suitable interposing relay/contactor if
  needed. A future coolant-flow fault should inhibit spindle operation.

## Read-only VFD parameter backup

The `PD000`–`PD250` capture issued no write, run, stop, or frequency command.
Of 251 queries, 170 returned values, 81 returned CRC-valid unsupported-function
responses, and none ended in error.

- [`huanyang-hy02d223b-register-backup.md`](huanyang-hy02d223b-register-backup.md)
  is the generated human-readable table.
- [`data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json`](data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json)
  preserves every raw request and response.
- [`tools/read-huanyang-vfd.py`](tools/read-huanyang-vfd.py) constructs only
  Huanyang function `0x01` read requests.
- [`tools/render-huanyang-register-table.py`](tools/render-huanyang-register-table.py)
  regenerates the Markdown record from JSON.

Recovered values include communications as both command and frequency source,
400 Hz base/maximum, 13.40 Hz lower limit, reverse forbidden, and motor data of
220 V, 10.0 A, two poles, and 3000 rpm at 50 Hz. The captured 10.0 A conflicts
with the spindle paper's 6 A. Resolve it before commissioning; do not change the
VFD based on either unverified value.

The project PDF is not the same revision as the delivered handbook. The
delivered copy marks `PD035`–`PD040`, `PD067`–`PD069`, `PD079`, and
`PD184`–`PD250` reserved; documents `PD089`–`PD100` and `PD109`–`PD119`; and
describes `PD081`–`PD085` differently. Those observations take precedence in
the generated table. Untranscribed conflicts remain pending.

Although the handbook reserves `PD184`–`PD250`, the VFD returned `PD184=20`,
`PD185=0`, `PD186=0`, and `PD200=0`. Preserve them as unexplained forensic
observations and never assign them a meaning or write them.
