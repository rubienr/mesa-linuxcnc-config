# Current CNC hardware documentation

This directory is the source of truth for the machine as it is migrated to
LinuxCNC and a Mesa 7I95T. It records verified hardware, facts recovered from
the legacy Machinekit setup, known errors in the old schematic, and questions
that still require a nameplate photo or physical inspection.

The files under
[`../legacy/beaglebone-black-panther-cape/`](../legacy/beaglebone-black-panther-cape/)
remain the forensic reference. Most of the machine wiring is expected to stay
the same, but legacy drawings and configuration must not be treated as correct
without verification.

## Status labels

- **Confirmed**: stated by the owner or unambiguously recorded in the legacy
  configuration/documentation.
- **Legacy-derived**: recovered from the old configuration; verify before
  energizing the rebuilt machine.
- **To verify**: plausible or shown in a drawing, but not yet confirmed on the
  physical machine.

## Safety boundary

This documentation is not yet an approved wiring diagram. Do not energize the
spindle, stepper drives, pump, vacuum equipment, or other mains-powered loads
from the benchmark LinuxCNC configuration. The old schematic contains known
errors and omissions. Verify protective earth, fusing, conductor sizes,
isolation, contact ratings, emergency-stop behavior, and every Mesa I/O voltage
before connecting field wiring.

## Known hardware

| Function | Manufacturer/model | Known details | Status |
| --- | --- | --- | --- |
| Motion controller | Mesa 7I95T | Ethernet; six differential step/dir channels, encoder inputs, 24 isolated field inputs, six isolated outputs; card powered from regulated 5 V | Confirmed |
| Stepper drive X/Y/Z | Leadshine AM882HN | Three drives; legacy drawing symbols say `AM882H-SFQ`; 20–80 VDC class, up to 8.2 A peak | Confirmed from legacy documentation; photograph labels/suffixes |
| X/Y stepper motors | Sanyo Denki StepSyn `103H7126-0703` | 1.8 degrees/step, recorded as 3 A | Legacy-derived; drawing instead reads `103H7126-07G3`, so verify nameplates |
| Z stepper motor | Vexta `C1824-9212H` | 1.8 degrees/step, 3.27 A, 3.66 V in the inventory | Legacy-derived; drawing appears to read `C8124-9212H`, so verify nameplate |
| `U1`, stepper-drive supply | Manufacturer/model unknown | Fanless replacement marked 230 VAC, 5 A input and 56 VDC output; replaces the formerly documented TDK-Lambda HWS1000-48 | Confirmed ratings from the installed unit; manufacturer, model and DC output-current rating still needed |
| `U2`, auxiliary supply | Glendale Electronic Components Pte. Ltd. `GE-003` | 230 VAC input; +5 VDC/2 A, −5 VDC/1 A and +12 VDC/2.5 A outputs | Confirmed from installed-unit marking; document terminal pinout and consumers |
| Spindle inverter | Huanyang `HY02D223B` | HY-series, 2.2 kW, 220 V class; read-only register capture confirms RS-485 at 19,200 baud, 8N1 RTU, address 1 | Confirmed model and current settings |
| Legacy VFD interface | BerryBase `USB-RS485` adapter, Amazon ASIN [`B09KV6TG3K`](https://www.amazon.de/dp/B09KV6TG3K) | CH340C USB/UART bridge and physically observed MAX485 ESA transceiver; two-wire RS-485 screw terminal; no galvanic isolation; one adapter failed without an identified cause | Confirmed legacy hardware; replacement architecture undecided |
| Spindle | Unidentified Chinese 2.2 kW ER20 water-cooled spindle | 220 VAC, 6 A, 0–400 Hz, 10,000–24,000 rpm, 80 mm cylindrical stainless body, about 250 mm body length, 4.9 kg | Confirmed from supplied paper and physical description; maker/model unknown |
| Limit sensors | Eight `LJ12A3-4-Z/AX` inductive proximity switches | Three-wire NPN, normally closed, nominal 4 mm range; X and Y each have min, home and max; Z has min and max but no separate home | Count, positions and visible labels confirmed; electrical behavior and cable destinations still require testing |
| Wireless pendant | XHC `WHB04B-6` | Rear label includes `MACH3`, `WHB04B-6`, `QC01` and `2017-05`; upstream describes this as a six-axis pendant. Connected USB receiver identifies as `10ce:eb93`, manufacturer `KTURT.LTD` | Model marking and receiver USB identity confirmed; live packet test remains |
| Fixed tool-height sensor | Model unknown | Used for automatic relative tool-length measurement | Confirmed function; electrical/mechanical details unknown |
| Workpiece touch-off probe/plate | Model unknown | Supports X, Y and Z workpiece touch-off | Confirmed function; plate dimensions and wiring require verification |
| Water pump | Model unknown | Supplies spindle coolant; believed connected to VFD relay terminal `FA(MB)` or, less certainly, `FC(MB)` | Relay group is identified, but the exact terminal/contact and pump ratings still require verification |

### Spindle paper specification

The spindle arrived with a typewritten sheet rather than a credible
manufacturer datasheet. Its text is retained here as evidence, including the
obvious errors:

| Paper entry | Recorded value | Interpretation |
| --- | --- | --- |
| Description | “2.2kw ER20 square water cooled spindle motor engraving milling grind” | The installed unit is cylindrical, not square. |
| Material | Stainless steel | Retain pending inspection. |
| Power | 2.2 kW | Accepted. |
| Voltage | 220 VAC | Accepted. |
| Current | 6 A | The paper calls this “electricity”; verify against a nameplate and VFD parameters. |
| Frequency | 0–400 Hz | Accepted as the stated range. |
| Speed | 10,000–24,000 rpm | Accepted as stated; do not infer that operation near 0 Hz is safe. |
| Cooling | “air-cooled” | Wrong: the installed spindle is water-cooled. |
| Runout | at most 0.01 mm | Wording on the sheet: “out of roundness”. Measurement conditions are unknown. |
| Taper bore precision | at most 0.005 mm | Measurement conditions are unknown. |
| Bearings | Four ceramic bearings; grease lubrication | These statements do not conflict: ceramic or hybrid-ceramic spindle bearings may be grease-lubricated. Exact bearing type is unknown. |
| Collet | ER20 | Accepted. |
| Net weight | 4.9 kg | Accepted as stated. |

Until a spindle nameplate or reliable supplier record is found, program the
VFD only from verified motor data. In particular, verify rated current,
frequency, minimum safe speed, pole count/rated rpm, acceleration and braking
parameters, and coolant-flow requirements.

## Stepper drive configuration recovered from the legacy notes

These values describe the old working setup, not a command to reprogram a
drive without first reading its current configuration.

| Setting | X | Y | Z |
| --- | ---: | ---: | ---: |
| Peak current | 3.3 A | 3.3 A | 3.5 A |
| Idle current | 50% | 50% | 50% |
| Idle timeout | 2,000 ms | 2,000 ms | 2,000 ms |
| Electrical damping | 1,000 | 1,000 | 1,000 |
| Alarm polarity | Active low | Active low | Active low |
| Active step edge | Rising | Rising | Rising |
| Direction definition | Low | Low | Low |
| Phase-error detection | Enabled | Enabled | Enabled |
| Sensorless stall detection | Enabled | Enabled | Enabled |
| Pulse smoother | Disabled | Disabled | Disabled |
| ENA reset / high-active ENA | Enabled | Enabled | Enabled |

The legacy notes say pulse smoothing caused sporadic lost steps and was
therefore disabled. They also record a historical change from a 24 V toroidal
supply to an HWS1000-48, which substantially reduced resonance problems. That
HWS1000-48 was later replaced by the presently installed fanless 56 VDC `U1`.

## Machine coordinate envelope and homing

Values below are taken from the last active legacy INI. They are software
limits in machine coordinates, not verified mechanical measurements.

| Axis | Minimum | Maximum | Configured span | Home position | Home offset | Home sensor/direction | Max velocity | Max acceleration |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| X | 61 mm | 571 mm | 510 mm | 62 mm | 60 mm | X−, search toward negative | 35 mm/s | 85 mm/s² |
| Y | 14 mm | 491 mm | 477 mm | 490 mm | 492 mm | Y+, search toward positive | 35 mm/s | 85 mm/s² |
| Z | −130 mm | 0.5 mm | 130.5 mm | 0 mm | 1 mm | Z+, search toward positive/up | 35 mm/s | 85 mm/s² |

The legacy scale was `80 steps/mm` for X and Y and `-80 steps/mm` for Z. Z was
homed first (`HOME_SEQUENCE=0`), followed by X and Y together
(`HOME_SEQUENCE=1`). Re-establish directions, scale, usable travel and braking
distance during commissioning; do not copy limits blindly.

```text
Top view (legacy machine coordinates; not to physical scale)

                         Y+ / home near 490 / limit 491
                         ^
                         |  configured Y span: 477 mm
                         |
 X- / home near 62       +------------------------------> X+
 X limit 61                 configured X span: 510 mm       X limit 571

Side convention:

 Z+ / home 0 / upper limit 0.5
 ^
 |
 |  configured Z span: 130.5 mm
 v
 Z- / lower limit -130
```

### Limit and home sensors

Physical inspection confirms the eight sensors drawn in the old schematic:

| Number | Machine label | Confirmed position/function |
| ---: | --- | --- |
| 4 | `X-` | X minimum |
| 5 | `XH` | Dedicated X home |
| 6 | `X+` | X maximum |
| 3 | `Y+` | Y maximum |
| Not yet recorded | `YH` | Dedicated Y home |
| Not yet recorded | `Y-` | Y minimum |
| 8 | `Z-` | Z minimum |
| 7 | `Z+` | Z maximum |

There is no separate Z-home sensor. The active legacy HAL ignored the
dedicated `XH` and `YH` inputs and instead combined X−, Y+ and Z+ with the
respective home signals. The new Mesa configuration can use the dedicated X/Y
home sensors, but their exact positions, polarity and desired homing sequence
must be tested first. Decide explicitly whether Z+ remains both home and upper
limit.

## Legacy sensor-interface workaround and Mesa migration

The inductive sensors need a supply above the logic voltage (historically at
least about 8 V was needed), while the Panther/BeagleBone input could not
tolerate the sensor voltage directly. The old schematic therefore contains a
non-obvious level-protection/interface workaround. Treat that circuitry as a
legacy Panther-specific solution, not as the required Mesa circuit.

The 7I95T manual specifies isolated inputs that operate from 4–36 VDC and can
use positive or negative common for sourcing or sinking applications. This is
a much more natural interface for 6–36 V NPN sensors. The exact common,
polarity, sensor supply, fuse, shielding and input allocation must still be
designed and tested. Do not carry the Panther level-shifting network into the
new design merely because it appears in the old drawing.

## Spindle, inverter and coolant

- The inverter is a Huanyang `HY02D223B`.
- The installed spindle is the 2.2 kW water-cooled ER20 unit documented above.
- The legacy configuration controlled the inverter through the `hy_vfd`
  userspace component over `/dev/ttyUSB0`: 19,200 baud, 8N1, target address 1.
- The old UI used 800 rpm as its default and allowed commands up to 24,000 rpm.
  This does **not** establish a safe minimum spindle speed.
- The old `hy_vfd` process opened `/dev/ttyUSB0` through a BerryBase
  `USB-RS485` adapter, sold on Amazon under ASIN
  [`B09KV6TG3K`](https://www.amazon.de/dp/B09KV6TG3K). BerryBase documents a
  CH340C chipset; the physical board also carries a MAX485 ESA transceiver.
  It is non-isolated and one unit has already failed, so it is retained as
  legacy evidence rather than a protection design reference.
- Some sales descriptions use `TTL` for this adapter. That describes the
  internal single-ended UART logic between the CH340C USB/UART bridge and the
  MAX485 transceiver, not the external screw-terminal signal. The MAX485
  converts that internal logic to a differential two-wire RS-485 bus. The VFD
  `RS+`/`RS-` terminals are RS-485, not TTL-level UART pins.
- The 7I95T serial channel 0 supports two-wire, low-speed RS-485 and its manual
  explicitly discusses Modbus use. The TB4 serial port is not one of the
  galvanically isolated field I/O circuits, however, and Mesa PktUART is not a
  `/dev/ttyUSB*` device. Replacing the adapter with the Mesa port therefore
  needs an isolation decision plus different LinuxCNC driver/configuration;
  it is not a wire-for-wire software replacement. See [`TODO.md`](TODO.md).
- The Ebyte `E810-R12` is being considered as the external isolation stage.
  It is a transparent, isolated one-host-to-two-slave RS-485 hub, not currently
  confirmed as purchased or installed. Its `IN` and `CH1`/`CH2` ports each use
  one differential A/B pair; `CH1` and `CH2` are duplicated branches, not
  separate receive and transmit channels.
- The water pump is absent from the old KiCad schematic. The corrected physical
  observation is that it is connected to `FA(MB)` or, less likely, `FC(MB)`;
  the exact terminal still needs checking.
- The available terminal documentation is internally inconsistent. Its table
  shows `FA(MB)`, `FB(MA)`, `FC(MA)`, while the basic connection diagram orders
  them as `FC(MA)`, `FA(MB)`, `FB(MA)`. The table states 3 A at 250 VAC for all
  three, while the diagram also mentions 3 A at 30 VDC. The most likely
  interpretation is that these aliases are the three `FA/FB/FC` contacts of a
  single changeover multifunction relay, but that remains an inference until
  the physical terminal labels and contact continuity are checked.
- The read-only parameter capture shows one auxiliary pump configured
  (`PD130=1`) and non-default pump/sleep values in `PD133`–`PD139`. However,
  multifunction outputs `PD050`–`PD053` are assigned to in-run, set-frequency,
  accelerating and disabled—none is assigned function 25, auxiliary pump 1.
  Trace the physical circuit and verify how the pump is actually switched.
- Verify the switching contact's type and rating against the pump. If it is
  unsuitable, use it only to control a correctly rated interposing
  relay/contactor.
- A future flow switch or coolant-fault input should inhibit spindle operation;
  none is currently documented.

### Read-only VFD parameter backup

The parameter space `PD000`–`PD250` was captured without issuing a write, run,
stop or frequency command. Of 251 queries, 170 returned values, 81 returned a
CRC-valid unsupported-function response and none ended in an error. Beyond the
supplied local manual's last documented parameter, `PD183`, the VFD returns
`PD184=20`, `PD185=0`, `PD186=0` and `PD200=0`; their meanings are unknown.

- [`huanyang-hy02d223b-register-backup.md`](huanyang-hy02d223b-register-backup.md)
  is the human-readable table with names, decoded units and purpose.
- [`data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json`](data/huanyang-hy02d223b-registers-pd000-pd250-2026-09-19.json)
  preserves every raw request and response frame.
- [`tools/read-huanyang-vfd.py`](tools/read-huanyang-vfd.py) is the deliberately
  read-only capture program. It constructs only Huanyang function `0x01`
  requests.

Important recovered values include communications as both the run-command and
frequency source, a 400 Hz base/maximum frequency, a 13.40 Hz lower limit,
reverse forbidden, and motor data of 220 V, 10.0 A, two poles and 3000 rpm at
50 Hz. The captured 10.0 A motor current conflicts with the informal spindle
paper's 6 A value. Resolve that discrepancy before commissioning rather than
changing the VFD from either unverified source.

The human-readable table includes the factory setting printed in the supplied
project PDF. Physical comparison has established that this PDF is **not the
same revision as the handbook delivered with the installed VFD**. The delivered
handbook marks `PD035`–`PD040`, `PD067`–`PD069` and `PD079` reserved; documents
`PD089`–`PD100` and `PD109`–`PD119`; and gives different descriptions for
`PD081`–`PD085`. It also marks the complete `PD184`–`PD250` range reserved.
These corrections take precedence in the register table.
Descriptions and factory values not yet transcribed from the delivered
handbook are marked pending rather than copied from the mismatched PDF.

The local 60-page PDF ends at `PD183`. Scan or photograph the delivered
handbook's parameter pages and preserve its cover, model scope and revision so
the remaining descriptions and factory values can be incorporated accurately.
Although `PD184`–`PD250` are reserved, the read-only capture found values at
`PD184=20`, `PD185=0`, `PD186=0` and `PD200=0`; these are retained as forensic
observations and must not be assigned a function or written.

## Tool measurement and workpiece touch-off

The legacy setup contains two distinct probing capabilities that should be
preserved in the LinuxCNC configuration.

### Automatic relative tool-length offset

`M600` starts a job and makes the next tool the reference. The remapped `M6`
routine then:

1. stops the spindle and coolant;
2. raises Z to the safe machine level;
3. moves to the fixed tool-height sensor;
4. performs a coarse and fine `G38.2` probe;
5. records the first tool as the reference, or calculates a relative length for
   later tools;
6. applies a dynamic `G43.1` tool offset; and
7. returns to the prior position, corrected for the new tool length.

Recovered legacy positions and feeds:

| Item | Value |
| --- | ---: |
| Coarse sensor X/Y | X 62 mm, Y 489 mm |
| Fine sensor X/Y | X 77 mm, Y 489 mm |
| Safe/travel Z | 0 mm |
| Fast approach Z | −55 mm |
| Lowest probe Z | −129 mm |
| Retract | 1 mm |
| Coarse probe feed | 180 mm/min |
| Fine probe feed | 10 mm/min |
| Manual tool-change X/Y | X 120 mm, Y 50 mm |

Every coordinate must be revalidated after the controller migration. A wrong
fixed-sensor coordinate or polarity can crash the tool into the table.

### Workpiece touch-off probe

The legacy `probe-touch-off.ngc` can touch X, Y or Z with `G38.2` and update the
active work coordinate system using `G10 L2`. The old pendant commands used a
10 mm maximum probing move at 15 mm/min, with 10.00 mm X/Y plate thickness and
26.40 mm Z plate thickness. Verify actual plate dimensions before reuse.

The fixed tool sensor and removable workpiece probe shared
`motion.probe-input` in the old configuration. The new wiring and HAL must make
their combination and fault behavior explicit.

## Wireless pendant

The installed pendant's Chinese rear label includes the Latin text `MACH3`,
`WHB04B-6`, `QC01` and `2017-05`; it does not show a firmware version. This
corrects the earlier `WHB08B-4:4` transcription. The installed LinuxCNC manual
describes `WHB04B-6` as a six-axis pendant; selector behavior will be verified
during the live input test.

The connected receiver is directly identified by the kernel as USB vendor and
product `10ce:eb93`, manufacturer `KTURT.LTD`, USB 1.10, with no product or
serial string. These IDs exactly match the constants used by the installed
LinuxCNC `xhc-whb04b-6` component. Arch's `lsusb` command was not installed,
but `/sys/bus/usb/devices/3-2/` and the `hidraw` uevent provide the same
authoritative descriptor values.

A standalone `xhc-whb04b-6 -ue -t` probe could not open the receiver because
its USB and `hidraw` device nodes currently lack write/access permission for
the desktop user and no matching udev rule is installed. USB identity is
therefore confirmed, while live decoding of this particular pendant's button,
selector and jog-wheel reports remains to be tested after access is configured.

The driver was reverse-engineered and is now present in upstream LinuxCNC at
[`src/hal/user_comps/xhc-whb04b-6`](https://github.com/LinuxCNC/linuxcnc/tree/master/src/hal/user_comps/xhc-whb04b-6).
Its protocol notes say the checksum expression for button-pressed packets is
not reliable for all seeds and that it is unknown whether the device uses a
CRC or a hand-crafted algorithm. This was the one unresolved protocol detail
during the original development; it does not mean the basic pendant support
is absent.

## Front-panel switches

The following physical switches exist and must be traced for future I/O,
interlock and schematic planning:

| Switch | Stated function | Details still needed |
| --- | --- | --- |
| Monitor | Monitor power on/off | Voltage, fuse and whether switching mains or low voltage |
| Vacuum relay | 230 V vacuum relay on/off | Relay/contactor model, coil voltage, contact rating and controlled outlet/load |
| Auxiliary power | 5 V and 12 V peripherals, such as lighting | Power-supply models, rail currents, fusing and consumers |
| Spindle power | Spindle/VFD power on/off | Whether it switches VFD mains directly or drives a contactor; interlock behavior |
| Stepper-driver power | Stepper-drive supply on/off | Contactor/switch arrangement, discharge time and current `U1` behavior |
| Vacuum pump | Vacuum-pump on/off | Pump model, voltage/current and distinction from the vacuum-relay switch above |

These manual controls must be represented in the future schematic even if they
do not connect to LinuxCNC.

## Known errors and annotations in the legacy schematic

The paper drawing is marked revision 0.19 and dated 2018-12-19. Handwritten
annotations and later discoveries establish the following:

1. The entire **Spindle Motor Driver** block is crossed out. Its JYQD V7.3Ei,
   Hall-sensor and associated spindle representation are not the installed
   Huanyang VFD/2.2 kW induction-spindle system.
2. The water pump and its direct connection to the Huanyang VFD relay are
   missing.
3. The drawn HWS1000-48 (`U1`) was replaced. The current fanless `U1` is marked
   for 230 VAC, 5 A input and 56 VDC output. The handwritten “not 48 V but 56”
   annotation therefore records the replacement supply's output rather than an
   out-of-range adjustment of the former HWS1000-48. Its manufacturer, model
   and DC output-current rating remain to be recorded.
4. There is an exclamation mark beside driver-enable switch `SW4A`; its reason
   is unknown. Treat the enable circuit and polarity as suspect until traced.
5. At the N9510 module, pin 3 is annotated as going to two electrolytic
   capacitors in parallel to ground, with one capacitor also associated with
   two series resistors to ground. No R/C values are written and it may only
   have been a planned change. Inspect the hardware rather than reconstructing
   this network from the note.
6. The drawn `U2` (`KS400A-230S24-SCN`) was replaced by a Glendale Electronic
   Components Pte. Ltd. `GE-003`, marked 230 VAC input and outputs of
   +5 VDC/2 A, −5 VDC/1 A and +12 VDC/2.5 A.
7. The old sensor voltage-conditioning arrangement belongs to the Panther
   interface and should not be copied into the Mesa design without analysis.

## Datasheets and manuals

Files are stored locally so that later work does not depend on product pages
remaining online.

| File | Scope and caveat |
| --- | --- |
| [`datasheets/mesa-7i95t-manual.pdf`](datasheets/mesa-7i95t-manual.pdf) | Manufacturer manual for the installed controller. |
| [`datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf`](datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf) | Manufacturer user manual for the E810-R12/R14/R18 isolated RS-485 hubs, revision 1.1 dated 2024-08-02. The E810-R12 is only a candidate external isolation stage; it is not confirmed as purchased or installed. |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages.pdf`](datasheets/huanyang-hy-series-instruction-67-numbered-pages.pdf) | Strong matching-handbook candidate: English Huanyang/Y&F instruction manual with 67 numbered content pages. The source scan stored facing pages in 36 landscape sheets; this project copy separates them into 69 convenient PDF pages including the cover and catalogue. It contains the corrected reserved ranges, 16-speed parameters, `FA(MB)`/`FB(MA)`/`FC(MA)` aliases and `PD184`–`PD250` reserved. |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.pdf`](datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.pdf) | Searchable OCR derivative of the matching handbook. The page images are retained with an English text layer; OCR text can contain recognition errors and must be checked against the scan before safety-relevant use. |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.txt`](datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.txt) | Plain-text OCR sidecar for fast searching, scripting and AI-assisted parameter comparison. It is an aid, not an authoritative replacement for the scanned pages. |
| [`datasheets/huanyang-hy-series-0.75kw-2.2kw-official-2024.pdf`](datasheets/huanyang-hy-series-0.75kw-2.2kw-official-2024.pdf) | One-page product brochure from Huanyang's website, not the expected operating handbook. Retained only as an official product/terminal reference. |
| [`datasheets/huanyang-hy02d223b-manual.pdf`](datasheets/huanyang-hy02d223b-manual.pdf) | Searchable 60-page HY-series owner’s manual. Its specifications and terminal tables explicitly contain `HY02D223B`; confirm the panel/terminal layout and revision against the physical VFD. |
| [`datasheets/leadshine-am882-manual.pdf`](datasheets/leadshine-am882-manual.pdf) | AM882 manual preserved by a third party because the original legacy Leadshine URL is dead. |
| [`datasheets/lj12a3-4-z-ax-reference.pdf`](datasheets/lj12a3-4-z-ax-reference.pdf) | Third-party reference sheet for the same generic sensor designation; installed manufacturer is not known. |
| [`datasheets/tdk-lambda-hws1000-installation-manual.pdf`](datasheets/tdk-lambda-hws1000-installation-manual.pdf) | Manufacturer manual for the former HWS1000 supply retained as legacy evidence; it does not describe the installed replacement `U1`. |
| [`datasheets/sanyo-denki-sanmotion-f2-catalog.pdf`](datasheets/sanyo-denki-sanmotion-f2-catalog.pdf) | Manufacturer family catalog. It does not resolve the `0703` versus `07G3` suffix discrepancy. |

Do not substitute a family manual for the actual nameplate when choosing
voltage, current, protection or VFD parameters.

## Proposed format for the new wiring source of truth

Before drawing the new KiCad schematic, maintain a small, reviewable CSV or
YAML connection list. CSV is sufficient and can be read by people, scripts and
AI tools:

```text
net,from_device,from_pin,to_device,to_pin,voltage,wire_color,wire_size,shield,fuse,notes
X_STEP,MESA7I95T,STEP0+,DRIVE_X,PUL+,5V,...
```

Use stable device identifiers and a separate device table containing model,
function, supply and datasheet. This can later drive consistency checks or a
SKiDL/KiCad-generation script. WireViz YAML is another good option for cable
and harness drawings, but it is not a complete substitute for a mains/control
schematic. The practical approach is:

1. inventory devices and terminals;
2. record every point-to-point connection in CSV/YAML;
3. review voltage domains, commons, shields, fuses and interlocks;
4. generate/check supporting views with scripts; and
5. create the authoritative KiCad schematic from the reviewed data.

## Open questions and commissioning work

All unresolved facts, investigations and migration tasks are maintained in
[`TODO.md`](TODO.md). Keep that checklist current as nameplates are photographed,
cables are traced and functions are bench-tested.
