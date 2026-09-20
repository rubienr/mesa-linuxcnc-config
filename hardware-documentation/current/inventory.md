# Current hardware inventory

Status terms are defined in [`README.md`](README.md). Unknown model suffixes and
ratings remain open work in [`TODO.md`](TODO.md).

## Known hardware

| Function | Manufacturer/model | Known details | Status |
| --- | --- | --- | --- |
| Motion controller | Mesa 7I95T | Ethernet; six differential step/dir channels, encoder inputs, 24 isolated field inputs, six isolated outputs; regulated 5 V card supply | Confirmed |
| Stepper drives X/Y/Z | Leadshine AM882HN | Three drives; legacy symbols say `AM882H-SFQ`; 20–80 VDC class, up to 8.2 A peak | Legacy documentation; photograph suffixes |
| X/Y motors | Sanyo Denki StepSyn `103H7126-0703` | 1.8 degrees/step, recorded as 3 A; drawing says `103H7126-07G3` | Legacy-derived; verify nameplates |
| Z motor | Vexta `C1824-9212H` | 1.8 degrees/step, 3.27 A, 3.66 V; drawing appears to say `C8124-9212H` | Legacy-derived; verify nameplate |
| `U1`, drive supply | Unknown | Fanless replacement marked 230 VAC, 5 A input and 56 VDC output; replaced the documented HWS1000-48 | Ratings confirmed; model and DC output rating to verify |
| `U2`, auxiliary supply | Glendale Electronic Components `GE-003` | 230 VAC input; +5 VDC/2 A, −5 VDC/1 A, +12 VDC/2.5 A | Marking confirmed; pinout and consumers to verify |
| Inverter | Huanyang `HY02D223B` | 2.2 kW, 220 V class; capture confirms 19,200 baud, 8N1 RTU, address 1 | Confirmed |
| Legacy VFD interface | BerryBase `USB-RS485`, ASIN [`B09KV6TG3K`](https://www.amazon.de/dp/B09KV6TG3K) | CH340C and observed MAX485 ESA; two-wire RS-485; no galvanic isolation; one failed unit | Confirmed legacy hardware; replacement undecided |
| Spindle | Unidentified Chinese 2.2 kW ER20 water-cooled spindle | 220 VAC, paper states 6 A, 0–400 Hz, 10,000–24,000 rpm, 80 mm body, about 250 mm long, 4.9 kg | Physical description and paper confirmed; maker/model unknown |
| Limit/home sensors | Eight `LJ12A3-4-Z/AX` | NPN normally closed, nominal 4 mm; X/Y each min, home, max; Z min/max | Count, positions, labels confirmed; electrical behavior and destinations to test |
| Pendant | XHC `WHB04B-6` | Label: `MACH3`, `WHB04B-6`, `QC01`, `2017-05`; receiver `10ce:eb93`, `KTURT.LTD` | Identity confirmed; live packet test remains |
| Fixed tool-height sensor | Unknown | Automatic relative tool-length measurement | Function confirmed; details unknown |
| Workpiece probe/plate | Unknown | X/Y/Z workpiece touch-off | Function confirmed; dimensions and wiring to verify |
| Water pump | Unknown | Spindle coolant; believed on VFD `FA(MB)` or possibly `FC(MB)` | Terminal and ratings to verify |

## Spindle paper specification

The spindle arrived with a typewritten sheet, not a credible manufacturer
datasheet. Preserve it as evidence, including its contradictions:

| Paper entry | Recorded value | Interpretation |
| --- | --- | --- |
| Description | “2.2kw ER20 square water cooled spindle motor engraving milling grind” | Installed body is cylindrical, not square |
| Material | Stainless steel | Pending inspection |
| Power / voltage / current | 2.2 kW / 220 VAC / 6 A | Verify current against nameplate and VFD settings |
| Frequency / speed | 0–400 Hz / 10,000–24,000 rpm | Does not establish safe operation near 0 Hz |
| Cooling | “air-cooled” | Wrong; installed spindle is water-cooled |
| Runout / taper precision | at most 0.01 mm / 0.005 mm | Measurement conditions unknown |
| Bearings | Four ceramic bearings; grease lubrication | Exact bearing type unknown |
| Collet / weight | ER20 / 4.9 kg | Accepted as stated |

Program the VFD only from verified motor data. Confirm rated current,
frequency, safe minimum speed, pole count/rated rpm, ramps, braking, and coolant
requirements first.

## Datasheets and manuals

| File | Scope and caveat |
| --- | --- |
| [`datasheets/mesa-7i95t-manual.pdf`](datasheets/mesa-7i95t-manual.pdf) | Manufacturer manual for the installed controller |
| [`datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf`](datasheets/ebyte-e810-r1x-user-manual-v1.1.pdf) | Manufacturer manual; E810-R12 is only a candidate isolation stage |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages.pdf`](datasheets/huanyang-hy-series-instruction-67-numbered-pages.pdf) | Strong matching-handbook candidate with corrected reserved ranges and terminal aliases |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.pdf`](datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.pdf) | Searchable derivative; check OCR against scan for safety-relevant use |
| [`datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.txt`](datasheets/huanyang-hy-series-instruction-67-numbered-pages-ocr.txt) | Search sidecar, not authoritative |
| [`datasheets/huanyang-hy-series-0.75kw-2.2kw-official-2024.pdf`](datasheets/huanyang-hy-series-0.75kw-2.2kw-official-2024.pdf) | Official one-page brochure, not an operating handbook |
| [`datasheets/huanyang-hy02d223b-manual.pdf`](datasheets/huanyang-hy02d223b-manual.pdf) | Searchable family manual explicitly containing this model; revision differs from delivered handbook |
| [`datasheets/leadshine-am882-manual.pdf`](datasheets/leadshine-am882-manual.pdf) | Third-party-preserved AM882 manual; original link is dead |
| [`datasheets/lj12a3-4-z-ax-reference.pdf`](datasheets/lj12a3-4-z-ax-reference.pdf) | Third-party generic sensor reference; installed maker unknown |
| [`datasheets/tdk-lambda-hws1000-installation-manual.pdf`](datasheets/tdk-lambda-hws1000-installation-manual.pdf) | Former supply only; not the installed replacement |
| [`datasheets/sanyo-denki-sanmotion-f2-catalog.pdf`](datasheets/sanyo-denki-sanmotion-f2-catalog.pdf) | Family catalog; does not resolve `0703` versus `07G3` |

Do not substitute a family manual for the actual nameplate when selecting
voltage, current, protection, or VFD parameters.
