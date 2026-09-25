# LinuxCNC runtime and machine configurations

This directory contains the shared CPU/IRQ affinity and launcher scripts plus
the staged Frida Mesa 7I95T commissioning profile under `frida-mesa/`. IRQ
numbers are discovered dynamically because they can change at boot.

## CPU and IRQ layout

| Logical CPU | Intended use |
| --- | --- |
| 0, 1, 3, 4, 6, 7, 9, 10 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 2 | Keep idle; SMT sibling of the Mesa IRQ CPU |
| 5 | Kernel-isolated and idle; SMT sibling of the servo CPU |
| 8 | Mesa Ethernet IRQ |
| 11 | LinuxCNC FIFO servo thread |

The affinity checker requires Wi-Fi IRQs to stay away from CPUs 2, 5, 8, and
11. CPU 5 and 11 are kernel-isolated; CPU 2 and 8 are reserved operationally
by the affinity and stress scripts.

> **Machine-safety warning:** The benchmark commands its stepgen enables and
> isolated SSR outputs false, but it is not a safety system. The Frida profile
> is not yet a verified machine configuration. Remove hazardous actuator power,
> use a hard E-stop, and verify wiring and polarity before commissioning work.

## Shared operating sequence

Apply network IRQ affinity once after each boot:

```bash
sudo ./thread-affinity-set.sh
```

The normal setter changes network IRQ placement only. LinuxCNC userspace RTAPI
receives `RTAPI_CPU_NUMBER=11` before launch so the realtime task starts on its
intended CPU. Use `sudo ./thread-affinity-set.sh --repair-running-rt` only when
the checker finds that an already-running RTAPI task has the wrong affinity.

The launcher intentionally has no default INI. Name the configuration so the
benchmark cannot be started accidentally on a connected machine:

```bash
LIBGL_ALWAYS_SOFTWARE=0 ./linuxcnc-start.sh \
    ../mesa-benchmark/mesa-7i95t-bench-1ms.ini
```

Once LinuxCNC is open, verify the new FIFO thread. The repository-root
convenience launchers perform this check automatically:

```bash
./thread-affinity-check.sh
```

Use `--brief` for a one-line result or `--wait-for-rt SECONDS` during startup.

`LIBGL_ALWAYS_SOFTWARE=0` selects hardware rendering. If AXIS crashes because
of a GPU/driver problem, retry diagnostically with
`LIBGL_ALWAYS_SOFTWARE=1`. Software rendering increases CPU load and may worsen
realtime latency, so repeat the Mesa and servo checks before relying on it.

The scripts accept `LAN_INTERFACE`, `WIFI_INTERFACE`, `LAN_IRQ_CPU`, and
`SERVO_CPU` overrides. Defaults match the host and kernel parameters documented
in `../archlinux/README.md`.

## Frida Mesa 7I95T commissioning profile

`frida-mesa/` migrates the three-axis Frida machine from the BeagleBone
Black/Panther Cape to LinuxCNC 2.9.10 and a Mesa 7I95T. It is based on the last
active Machinekit configuration, the revision 0.19 legacy schematic, current
hardware evidence, and the Mesa/Leadshine manuals.

Wire identities, polarities, voltage domains, hard E-stop behavior, travel,
and homing directions still require physical verification. All six Mesa SSR
outputs and the three unused step generators are commanded off. The three
unidentified two-wire cable bundles must remain insulated until traced.

### Profile files

- `frida-mesa/frida-mesa.ini`: machine, trajectory, joint, homing, and component
  settings.
- `frida-mesa/mesa.hal`: HostMot2 Ethernet load, thread order, and X/Y/Z step
  generators.
- `frida-mesa/general-signals.hal`: E-stop, limits, legacy homing, probe,
  alarms, and tool loopbacks.
- `frida-mesa/hy-vfd.hal`: Huanyang control through the existing USB/RS-485
  adapter.
- `frida-mesa/pendant.hal`: XHC WHB04B-6 integration.
- `frida-mesa/motion.hal`: final servo-thread ordering.
- `frida-mesa/wiring.csv`: proposed terminal-level allocation and eventual
  wiring source of truth.
- `frida-mesa/udev/70-xhc-whb04b-6.rules`: desktop-seat access for the pendant.

Hazardous legacy probe/tool-change MDI macros are not enabled. Pendant macro,
machine-home, safe-Z, work-home, probe-Z, and Fn-modified buttons remain
unassigned until the old NGC routines are reviewed and tested with spindle and
drive power removed.

### Allocation and electrical assumptions

- Step generators 0, 1, and 2 are X, Y, and Z on TB3.
- TB6 pairs group X, X, Y, Y, Z, probe, E-stop, and spare inputs.
- TB5 inputs 16 through 18 are X, Y, and Z drive alarms; 19 through 23 are
  reserved for traced future wiring.
- TB5 outputs 0 through 5 are unassigned.
- TB4 serial is unused because the current firmware exposes no PktUART HAL
  interface compatible with the existing `hy_vfd` tty path.

The initial step/direction allocation retains the existing common-anode wiring:

| Axis | Mesa terminals | AM882 terminals |
| --- | --- | --- |
| X | TB3-6 `+5VP`, TB3-2 `STEP0-`, TB3-4 `DIR0-` | PUL+/DIR+, PUL-, DIR- |
| Y | TB3-12 `+5VP`, TB3-8 `STEP1-`, TB3-10 `DIR1-` | PUL+/DIR+, PUL-, DIR- |
| Z | TB3-18 `+5VP`, TB3-14 `STEP2-`, TB3-16 `DIR2-` | PUL+/DIR+, PUL-, DIR- |

Leave STEP+/DIR+ and GND unconnected during this phase; never tie the unused
complementary output to ground or +5 V. Prove every conductor and drive-side
terminal before connection.

The eight limit/home sensors are NPN normally closed. The HAL uses HostMot2
`-not` pins so a target or broken output conductor appears asserted. Confirm
the sensor supply is within the Mesa input's 4--36 VDC range. For each sensor
pair, the proposal connects `INCOM` to fused sensor positive, black output to
the allocated input, and blue to sensor-supply 0 V. The recovered homing
behavior is X on X-, Y on Y+, and Z on Z+; dedicated X/Y home sensors remain
diagnostic until their positions and directions are tested.

`ESTOP_OK` on TB6 input 12 is status from the hardwired safety chain, not an
E-stop output. The hard circuit must remove hazardous energy independently.
Legacy evidence suggests probe and E-stop are positive-voltage switch signals,
with their paired `INCOM` terminals at field 0 V; prove this and do not share
their commons with the NPN sensor pairs.

The proposed drive-alarm circuit connects each Mesa `INCOM` to fused field
positive, `INPUT` to AM882 `ALM+`, and `ALM-` to field 0 V. Confirm polarity,
normal/fault states, and the shared-common arrangement before using a raw input
as a joint fault. An open-collector alarm is not automatically fail-safe for a
broken conductor.

Do not move the unresolved legacy `DRIVER_ENABLE` circuit to a Mesa SSR output.
Its `SW4A` annotation and ENA polarity/reset behavior must be traced with drive
power isolated. Disabling a step generator stops pulses but may leave motor
torque enabled.

The VFD profile retains the known tty path at 19,200 baud, 8N1, address 1:

```text
/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
```

The current CH340C/MAX485 adapter is not galvanically isolated. Verify serial
polarity, shielding, motor data, control-source parameters, and communication
loss behavior before energizing the spindle.

Install the pendant access rule locally, then reconnect the receiver:

```bash
sudo install -m 0644 frida-mesa/udev/70-xhc-whb04b-6.rules \
    /etc/udev/rules.d/70-xhc-whb04b-6.rules
sudo udevadm control --reload-rules
```

Test every selector, wheel mode, and button with drives and spindle disabled.

### Commissioning order

1. Disconnect mains loads, stepper supply, and VFD/spindle power; bond Mesa
   frame ground and verify its regulated 5 V supply.
2. Label and continuity-test every legacy conductor and complete the missing
   fields in `frida-mesa/wiring.csv`.
3. Connect only Ethernet, Mesa 5 V, field-input supply, and inputs; verify raw
   and inverted pins with HAL tools.
4. Prove every E-stop device and safety-chain power loss opens `ESTOP_OK` and
   independently removes hazardous energy.
5. With motor power removed, connect step/direction and verify idle levels and
   polarity at each drive plug.
6. Energize one drive at a time at low velocity and acceleration; establish
   direction and both limits before homing.
7. Re-measure travel and braking margin; test Z first, then X and Y.
8. Validate the pendant with spindle disabled and macros unassigned.
9. Bench-test the VFD with the spindle power stage safe, including stop on
   E-stop, LinuxCNC exit, USB removal, timeout, and power loss.
10. Record final wiring before considering differential step/direction.

Launch only when no other LinuxCNC/HAL realtime session is active:

```bash
sudo ./thread-affinity-set.sh
RTAPI_CPU_NUMBER=11 LIBGL_ALWAYS_SOFTWARE=0 \
    ./linuxcnc-start.sh ./frida-mesa/frida-mesa.ini
```

Detailed physical evidence and open verification work live under
`../hardware-documentation/current/`.
