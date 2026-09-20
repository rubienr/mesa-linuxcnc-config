# Legacy discrepancies and wiring records

## Known errors and annotations in the legacy schematic

The paper drawing is revision 0.19 dated 2018-12-19. Treat these observations as
constraints on any migration:

1. The crossed-out **Spindle Motor Driver** block, JYQD V7.3Ei, Hall sensors,
   and spindle representation are not the installed Huanyang/induction-spindle
   system.
2. The coolant pump and its Huanyang relay connection are absent.
3. HWS1000-48 (`U1`) was replaced by a fanless supply marked 230 VAC, 5 A input,
   56 VDC output. The “not 48 V but 56” annotation refers to this replacement;
   model and DC output current remain unknown.
4. Driver-enable switch `SW4A` has an unexplained exclamation mark. Treat its
   circuit and polarity as suspect.
5. A note at N9510 pin 3 mentions two parallel electrolytic capacitors and two
   series resistors to ground without values. It may describe only a proposed
   change; inspect rather than reconstruct it.
6. Drawn `U2` (`KS400A-230S24-SCN`) was replaced by Glendale `GE-003`, marked
   230 VAC input and +5 VDC/2 A, −5 VDC/1 A, +12 VDC/2.5 A outputs.
7. The sensor voltage-conditioning network belongs to the Panther interface and
   must not be copied into the Mesa design without analysis.

## Current wiring source

Maintain a reviewable point-to-point record before producing a new KiCad
schematic. The current proposed allocation is
[`../../config/frida-mesa/wiring.csv`](../../config/frida-mesa/wiring.csv) with
fields for net, endpoints, voltage domain, logic, conductor, shielding, fuse,
status, and notes.

Use stable device identifiers and a separate device inventory. The sequence is:

1. inventory devices and terminals;
2. record every point-to-point connection;
3. review voltage domains, commons, shields, fuses, and interlocks;
4. generate or check supporting views; and
5. create the authoritative KiCad schematic from reviewed data.

WireViz may support cable and harness views but does not replace a mains/control
schematic. Track all unresolved tracing and design work in [`TODO.md`](TODO.md).
