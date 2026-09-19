# Hardware documentation and migration checklist

This file contains every known uncertainty or task that must be resolved before
the current machine schematic and production LinuxCNC configuration can be
considered complete. Check an item only after recording the result in
`README.md`, the connection inventory, or the future KiCad project.

Do not inspect, disconnect or measure energized mains equipment. Record
nameplates and wiring photographs before moving conductors.

## Highest-priority architecture decisions

### Complete the replacement power-supply records

Established facts:

- The drawn TDK-Lambda HWS1000-48 (`U1`) was replaced.
- Current `U1` is fanless and marked 230 VAC, 5 A input and 56 VDC output.
- The “not 48 V but 56” paper annotation refers to this replacement rather
  than an unreasonable HWS1000-48 adjustment.
- Drawn `U2` (`KS400A-230S24-SCN`) was replaced by Glendale Electronic
  Components Pte. Ltd. model `GE-003`, marked 230 VAC input, +5 VDC/2 A,
  −5 VDC/1 A and +12 VDC/2.5 A.

- [x] Record the complete `U2` nameplate: Glendale Electronic Components Pte.
  Ltd. `GE-003`; 230 VAC input; +5 VDC/2 A, −5 VDC/1 A and +12 VDC/2.5 A
  outputs.
- [ ] Photograph the complete `U1` unit and its nameplate. Photograph the
  terminals and installed wiring of both `U1` and `U2` for the new schematic.
- [ ] Record the manufacturer and exact model of the fanless 56 VDC `U1`.
- [ ] Record `U1`'s rated DC output current/power and clarify whether its 5 A
  marking is the AC input rating, recommended fuse, or another parameter.
- [ ] With an appropriate safe procedure and loading, measure `U1` output and
  record voltage, ripple and test conditions.
- [x] Confirm the nominal `U1` voltage against the AM882 rating: 56 VDC is
  within the 20–80 VDC supply range in the AM882 manual, page 3 (68 VDC
  typical, 80 VDC maximum).
- [ ] Verify that the live DC bus remains below the AM882's 80 VDC maximum
  under high mains, deceleration/regeneration and switching transients. The
  nominal-rating comparison alone cannot establish this worst case.
- [ ] Record the GE-003 terminal pinout, output commons/returns, fusing and
  every consumer on the +5 V, −5 V and +12 V rails.
- [ ] Document the GE-003 230 VAC input wiring, fuse/protection, disconnecting
  arrangement and protective-earth connection.

### Choose the Huanyang VFD communication interface

Legacy evidence:

- Huanyang inverter: `HY02D223B`.
- Legacy settings: 19,200 baud, 8 data bits, no parity, one stop bit, address 1.
- Legacy software: `hy_vfd` opening `/dev/ttyUSB0`.
- Adapter: BerryBase `USB-RS485`, sold on Amazon under ASIN
  [`B09KV6TG3K`](https://www.amazon.de/dp/B09KV6TG3K), with a green two-screw
  RS-485 terminal. BerryBase documents the CH340C USB/UART bridge; physical
  inspection additionally identified a MAX485 ESA transceiver, capacitors,
  resistors marked `222`, `224`, `223`, and a device marked `M6`.
- Any `TTL` wording in a sales description refers to the internal
  single-ended UART side between the CH340C and MAX485. The exposed two-wire
  screw terminal is differential RS-485 and must not be treated as a TTL UART
  connection.
- There is no galvanic-isolation barrier visible. The resistor markings mean
  nominally 2.2 kΩ, 220 kΩ and 22 kΩ; none is the usual 120 Ω termination.
- One such cheap adapter failed without an identified cause.

The Mesa 7I95T can electrically support a two-wire RS-485 link on TB4 serial
channel 0. For low-speed Modbus the manual says to join TX+ to RX+, join TX− to
RX−, and disable the channel-0 termination by moving W23 to the right. This
does not settle the system design:

- The TB4 RS-422/RS-485 interface is not documented as galvanically isolated.
  It shares 7I95T logic-side ground and 5 V connections; the separately
  described field inputs/outputs are the isolated circuits.
- Mesa PktUART does not appear as `/dev/ttyUSB0`, so the existing `hy_vfd`
  command cannot simply be pointed at it.
- LinuxCNC provides Mesa PktUART Modbus frameworks, but the LinuxCNC
  documentation notes that Huanyang devices do not implement normal Modbus
  completely and suggests the dedicated `hy-vfd` driver for most HY uses.
- The installed 7I95T firmware must expose a compatible PktUART before a Mesa
  implementation can work.

Choose and document one path:

- [ ] **Recommended initial path:** replace the non-isolated BerryBase adapter with a
  reputable, galvanically isolated USB-to-RS-485 adapter and retain the proven
  `hy_vfd` software interface.
- [ ] **Possible later path:** use Mesa serial channel 0, add an appropriate
  external galvanic isolator/isolated RS-485 stage if required, and implement
  or adapt a Huanyang-compatible PktUART driver/configuration. The Ebyte
  `E810-R12` is one candidate; its local manufacturer manual is
  [`datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf`](datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf).
- [ ] Confirm from the VFD documentation and terminal inspection whether its
  RS-485 port itself is isolated. Do not infer this from the differential A/B
  interface.
- [ ] Decide where cable shield and any signal reference connect; avoid an
  unintended VFD-to-controller ground loop.
- [ ] Record cable type, routing, length, A/B polarity, biasing and termination.
- [x] Read `PD000`–`PD250` with a function-`0x01`-only tool and verify the
  communication settings: address 1, 19,200 bit/s, 8N1 RTU. The decoded table
  and raw CRC-checked frames are stored in the current documentation. The VFD
  returned 170 values and 81 valid unsupported replies, with no errors.
- [x] Preserve the matching handbook, including its cover, terminal tables and
  complete parameter list, as both the original scan and a searchable OCR
  derivative with plain-text sidecar. It
  differs from the project PDF: `PD035`–`PD040`, `PD067`–`PD069` and `PD079`
  are reserved; `PD089`–`PD100` and `PD109`–`PD119` are documented; and
  `PD081`–`PD085` have different descriptions. It also marks `PD184`–`PD250`
  reserved.
- [ ] Transcribe the delivered handbook's exact names, descriptions and factory
  values for `PD081`–`PD085`, `PD093`–`PD100` and `PD109`–`PD116`; do not use
  the conflicting project PDF for these fields.
- [x] Classify `PD184`–`PD250` as reserved according to the delivered
  handbook. Preserve the values returned by four reserved registers as
  forensic observations, but do not infer functions or write them.
- [ ] Replace the temporary world-writable `/dev/ttyUSB0` permissions with a
  least-privilege `uucp` group or device-specific udev rule before routine use.
- [ ] Bench-test start, stop, direction, commanded speed, feedback, timeout and
  communication-loss behavior with the spindle power stage made safe.
- [ ] Confirm that loss of communication always results in the intended safe
  state and cannot leave the spindle running unexpectedly.

### Complete the XHC pendant checksum/CRC computation

The upstream
[`xhc-whb04b-6`](https://github.com/LinuxCNC/linuxcnc/tree/master/src/hal/user_comps/xhc-whb04b-6)
protocol notes still describe byte 7 of a received report as an unresolved
checksum. For jog-wheel, rotary-switch and button-release events the observed
relationship is `checksum == random & seed`. For button-press events the
candidate expression only works reliably with seeds `0xfe` and `0xff`; the
upstream note says an equation term is missing and it is unknown whether the
algorithm is a CRC or a hand-crafted checksum.

- [x] Confirm the installed receiver's USB identity matches the upstream
  component: the kernel reports `10ce:eb93`, manufacturer `KTURT.LTD`, exactly
  matching the VID/PID compiled into LinuxCNC `xhc-whb04b-6`.
- [ ] Add an appropriate least-privilege udev rule, then run the component in
  standalone diagnostic mode (`xhc-whb04b-6 -ue`) and exercise every button,
  both selectors and the jog wheel. Matching VID/PID identifies the receiver
  but does not by itself prove identical firmware packet behavior. The first
  probe failed because the desktop user cannot currently open the USB device.
- [ ] Capture a sufficiently large set of raw USB input/output reports covering
  every button and many seed/random values, especially seeds other than
  `0xfe`/`0xff`.
- [ ] Preserve captures plus a reproducible decoder/test program in the future
  LinuxCNC workspace; exclude no samples merely because they contradict the
  current candidate formula.
- [ ] Test standard CRC-8 variants, additive/XOR/bitwise checksums and possible
  state-dependent terms against the complete capture set.
- [ ] Determine whether a wrong or unchecked checksum affects only diagnostic
  output or can cause missed/false pendant actions in normal HAL operation.
- [ ] Implement the complete computation with unit tests and submit the fix and
  protocol documentation upstream if the algorithm is resolved.

## Tool measurement and touch-off migration

Preserve the custom routines, but review and test them before attaching their
outputs to real motion. Recovered legacy behavior:

| User action or command | Legacy signal/MDI command | Function |
| --- | --- | --- |
| `M600` in G-code or MDI | remapped to `tool-job-begin.ngc` | Marks the next `M6` as the first/reference tool for a new job |
| `Fn` + `Probe-Z` | pendant `macro-9` → `halui.mdi-command-09` → `M6` | Runs the remapped automatic tool-change/tool-length routine |
| `Probe-Z` without `Fn` | `halui.mdi-command-25` | Z workpiece touch-off using the legacy 26.40 mm plate value |
| `Fn` + `Macro-10` | pendant `macro-14` → `halui.mdi-command-14` | Calls `tool-reset-offset`, which executes `M600` and then `M6` |
| `M-HOME` | `halui.mdi-command-20` | Move to legacy machine-home coordinates |
| `Safe-Z` | `halui.mdi-command-21` | Move to machine Z=0 |
| `W-HOME` | `halui.mdi-command-22` | Move to workpiece origin using the custom routine |
| No pendant mapping recovered | `halui.mdi-command-23` | X+ touch-off, 10 mm probe move, 10.00 mm plate |
| No pendant mapping recovered | `halui.mdi-command-24` | Y+ touch-off, 10 mm probe move, 10.00 mm plate |

- [ ] Copy and port `tool-change.ngc`, `tool-job-begin.ngc`,
  `tool-reset-offset.ngc`, `probe-touch-off.ngc`, `go-machine-home.ngc` and
  `go-workpiece-home.ngc` into the new LinuxCNC configuration.
- [ ] Review Machinekit-era interpreter syntax and remap configuration against
  LinuxCNC 2.9 before running any routine.
- [ ] Decide and document the normal operator sequence. The likely sequence is
  `M600` once at job start, then `M6` for the reference tool and each later
  tool, but this must be confirmed safely.
- [ ] Decide whether `Fn + Macro-10` should remain a combined reset-and-probe
  action; its label does not communicate the hazardous motion it initiates.
- [ ] Decide whether X and Y workpiece touch-off should receive pendant buttons,
  GUI controls only, or remain MDI-only.
- [ ] Verify the fixed sensor and removable workpiece probe cannot be connected
  simultaneously in an ambiguous or unsafe way if they share
  `motion.probe-input`.
- [ ] Verify probe polarity and test an already-active/stuck probe fault before
  allowing any probing motion.
- [ ] Measure the workpiece plate thicknesses; do not reuse 10.00 mm or
  26.40 mm without measurement.
- [ ] Re-establish safe travel, coarse/fine sensor positions, lowest probe
  height, feed rates and retract distance on the rebuilt controller.
- [ ] Test every routine above the table with spindle power disabled and a
  generous sacrificial clearance before normal use.
- [ ] Write a short operator procedure after validation, including recovery
  from an interrupted or failed probe cycle.

## Unidentified pre-wired cables

There are three bunches containing two cables each—six cables in total—that
were wired into the machine but could not be connected to the Panther cape.

The strongest schematic match is legacy main-schematic connector `P11`,
labelled `OUT2 P4`: pins 7/8 are `OUT4/GND`, 9/10 are `OUT5/GND`, and 11/12
are `OUT6/GND`. Those are exactly three two-conductor output pairs and were not
assigned in the recovered HAL. This is a forensic hypothesis, not an
identification; the alternatives include spare step/direction, input, probe or
alarm wiring.

- [ ] Photograph each bunch at both ends before disturbing it.
- [ ] Assign durable temporary identifiers, for example `UNKNOWN-A1/A2`,
  `UNKNOWN-B1/B2`, and `UNKNOWN-C1/C2`.
- [ ] Record conductor count, colors, shield/drain, connector, approximate
  route and where each end physically terminates.
- [ ] With all power removed and stored energy discharged, perform continuity
  tracing and check for any connection to chassis/protective earth.
- [ ] Determine whether each is a switch/sensor input, power conductor, relay
  output, probe, alarm, pendant/control, or unused spare.
- [ ] Measure or infer the intended voltage domain only after the endpoints are
  known; never discover it by trial connection to Mesa.
- [ ] Add confirmed cables to the connection inventory and future KiCad
  schematic. Mark genuinely unused conductors as spare and insulate them.

## Component identity and ratings

- [ ] Find any spindle manufacturer/model/serial marking on the body or
  connector.
- [ ] Record the spindle connector pinout, conductor colors, shield termination
  and protective-earth/bond connection.
- [ ] Verify spindle rated current, pole count/rated rpm, bearings and safe
  minimum speed from a better source than the supplied paper.
- [ ] Photograph the HY02D223B nameplate and terminals; record input ratings and
  firmware/manual revision if available.
- [x] Export all readable VFD parameters, motor data, ramps, control source and
  RS-485 settings with raw frames. Relay/pump terminal mapping remains a
  separate unresolved physical-tracing task.
- [ ] Photograph all three Leadshine labels to resolve AM882HN/AM882H suffixes.
- [ ] Photograph X, Y and Z motor nameplates to resolve `0703`/`07G3` and
  `C1824`/`C8124` discrepancies.
- [ ] Identify every 5 V, 12 V and other auxiliary supply, including ratings,
  fuses and consumers.
- [x] Record the pendant label and receiver identity. The Chinese rear label
  contains `MACH3`, `WHB04B-6`, `QC01` and `2017-05`, with no visible firmware
  version. Kernel sysfs reports the connected receiver as `10ce:eb93` and
  `KTURT.LTD`; `lsusb` is not currently installed.

## Sensors, probes and motion

- [x] Count and identify all eight physical sensors: X− no. 4, X home no. 5,
  X+ no. 6, Y+ no. 3, Y home, Y−, Z− no. 8 and Z+ no. 7. There is no
  separate Z-home sensor.
- [x] Confirm that the two sensors omitted from active legacy HAL were the
  dedicated X-home and Y-home sensors, not spares.
- [ ] Record the visible number markings for `YH` and `Y-`, then trace every
  sensor cable, supply and Mesa destination and verify NPN-NC behavior.
- [ ] Identify the fixed tool-height sensor and document travel, overtravel,
  repeatability, polarity and safe coordinates.
- [ ] Identify the workpiece probe/plate and document its cable and dimensions.
- [ ] Measure physical axis travel, hard stops, screw pitch, coupling ratio,
  microstep setting and resulting steps/mm.
- [ ] Verify motion directions and identify physical X−/X+, Y−/Y+ and Z−/Z+.
- [ ] Confirm whether legacy software spans X 510 mm, Y 477 mm and Z 130.5 mm
  remain safe usable travel.
- [ ] Record table size, spindle-to-table envelope, gantry clearance, spindle
  mount dimensions and machine datum orientation.

## Pumps, switching, interlocks and protection

- [ ] Identify the spindle water pump's model, voltage/current, flow/head and
  fuse. Check whether its conductor is on `FA(MB)` or `FC(MB)` and record all
  three physical relay-terminal labels and wire positions.
- [ ] Resolve the terminal-documentation mismatch: the table lists `FA(MB)`,
  `FB(MA)`, `FC(MA)`, while the basic diagram orders `FC(MA)`, `FA(MB)`,
  `FB(MA)`. Verify with power removed which three terminals form the inferred
  `FA/FB/FC` changeover contact, identify common/NO/NC, and confirm whether the
  applicable contact rating is 3 A at 250 VAC and/or 3 A at 30 VDC.
- [ ] Reconcile `PD130=1` and pump settings `PD133`–`PD139` with the actual
  switching circuit. `PD050`–`PD053` currently do not assign auxiliary-pump
  function 25 to any of the four documented multifunction outputs.
- [ ] Record hose size, reservoir/radiator arrangement, normal flow and any
  flow/temperature interlock.
- [ ] Trace the reason for the `SW4A` exclamation mark and verify driver-enable
  polarity and fail-safe behavior.
- [ ] Inspect whether the N9510 capacitor/resistor annotation was implemented;
  record values and purpose if present.
- [ ] Identify the vacuum relay/contactor and the separate vacuum pump/load;
  clarify what each of the two front-panel switches controls.
- [ ] Trace all six front-panel switches and record terminals, voltage, load
  and protection.
- [ ] Document emergency-stop devices, safety relay/contactor chain, reset
  behavior and which energy sources are removed.
- [ ] Record every fuse/breaker, contactor, relay, filter, braking resistor,
  protective-earth and shield connection.

## Documentation deliverables

- [ ] Create the device inventory with stable reference identifiers.
- [ ] Create the point-to-point connection CSV/YAML described in `README.md`.
- [ ] Record every resolved checklist result in the main documentation.
- [ ] Create and review the corrected KiCad schematic.
- [ ] Generate a PDF schematic and wiring/terminal schedules.
- [ ] Create a Mesa I/O allocation table and cross-reference it to HAL signal
  names and KiCad net names.
- [ ] Create commissioning test sheets for power, E-stop, limits, drives,
  probing, spindle communication, coolant and vacuum equipment.
