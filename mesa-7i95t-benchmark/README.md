# Mesa 7I95T benchmark

This directory tests HostMot2 Ethernet communication with the Mesa 7I95T at
`192.168.1.121` under sustained system load. It uses the firmware already on
the card, does not flash it, and explicitly commands all six stepgen enables
and all six isolated SSR outputs false.

> **Danger:** Connect only Ethernet and the required card power for this bench
> test. Do not connect the 7I95T step/direction, spindle, SSR, or field-I/O
> terminals to an energized machine. The configuration should not request
> motion, but it is not a safety function; a configuration, software, polarity,
> or wiring error could still actuate machinery. If the card is already wired,
> remove drive/spindle power and use a hard E-stop before running this profile.

The primary profile is `mesa-7i95t-bench-1ms.ini` with a 1 ms servo period.
The `mesa-7i95t-bench-2ms.ini` profile is the 2 ms comparison; the associated
HAL, tool table, variable, and scope files are part of those configurations.

## Run it

Apply IRQ placement after every boot, then explicitly launch the 1 ms profile
with hardware rendering:

```bash
sudo "$HOME/linuxcnc/config/set-thread-affinity.sh"
LIBGL_ALWAYS_SOFTWARE=0 "$HOME/linuxcnc/config/start-linuxcnc.sh" \
    "$HOME/linuxcnc/mesa-7i95t-benchmark/mesa-7i95t-bench-1ms.ini"
```

After LinuxCNC creates its realtime thread, rerun the setter and checker:

```bash
sudo "$HOME/linuxcnc/config/set-thread-affinity.sh"
"$HOME/linuxcnc/config/check-thread-affinity.sh"
```

Start the reproducible CPU/memory load in another terminal. It excludes the
LinuxCNC and Mesa physical cores:

```bash
./start-stress-test.sh
```

Watch all benchmark-relevant HostMot2 error flags, read/write maxima, and the
servo-thread row in one display:

```bash
./watch-counters.sh
```

It refreshes once per second. Set `WATCH_INTERVAL` to another positive interval
or use `./watch-counters.sh --once` for a scriptable snapshot.

## Record intermittent communication errors

Use the diagnostic monitor to establish a counter baseline and append rich
snapshots when communication counters, timing maxima, NIC errors, affinity, or
the monitored workload changes:

```bash
./monitor-diagnostics.sh
```

The monitor samples once per second and writes a private, timestamped log below
`diagnostic-logs/`. Generated logs and the instance lock are ignored by Git;
only the directory placeholder and ignore rules are tracked. The monitor pins
itself and all child commands to CPUs `0-1,3-4,6-7,9-10`, away from the Mesa
and LinuxCNC physical cores.

The default mode is read-only: it does not start or stop LinuxCNC, reset HAL
state, or change affinity or network settings. A startup record contains the
absolute HAL, NIC, IRQ, process, kernel, and host baseline. Subsequent records
contain absolute values and deltas from both startup and the preceding sample.
Each complete record is bounded by matching `BEGIN_RECORD` and `END_RECORD`
lines, so an incomplete final record is easy to identify after an interruption.

Useful options include:

```bash
# Name the log and write a rich heartbeat every ten minutes.
./monitor-diagnostics.sh \
    --output mesa-long-run.log \
    --heartbeat 600

# Diagnostic-state mutation: reset only writable timing maxima after an event.
./monitor-diagnostics.sh --reset-tmax-after-event

# Safe short test: no HAL or network access, including a simulated failure.
./monitor-diagnostics.sh --mock --interval 0.1 --heartbeat 0.2 --max-samples 5
```

The reset option never clears packet-error totals, `io_error`, or other safety
state. It is disabled by default because resetting timing maxima changes the
diagnostic state. The monitor records the reset as a separate mutation record.

Follow a running log and stop a foreground monitor with `Ctrl-C`:

```bash
tail -F diagnostic-logs/mesa-long-run.log
```

For a background monitor, use the stop helper. It verifies the active lock and
process identity before sending `SIGTERM`, then waits for the monitor to append
its shutdown record and release the lock:

```bash
./stop-diagnostics.sh
```

Set another graceful-shutdown deadline with `--timeout SECONDS`. The helper
never sends `SIGKILL` and does not start, stop, or change LinuxCNC or HAL. The
monitor exits with status `130` after `SIGINT` and `143` after `SIGTERM`. Only
one monitor may run at a time; `diagnostic-logs/.monitor.lock` contains its PID
while it holds the instance lock.

Logs rotate at 64 MiB by default and retain five rotated files. Override this
with `--max-log-bytes` and `--rotated-logs`. To list complete records and their
types using standard tools:

```bash
awk '/^BEGIN_RECORD|^END_RECORD/' diagnostic-logs/mesa-long-run.log
```

One-second polling cannot reliably observe millisecond-wide Boolean error
flags. The cumulative packet-error total and monotonic timing maxima are the
durable triggers; transient flags are recorded whenever a sample sees them.

The optional communication-only check is `halrun validate-7i95t.hal` when no
other HAL session is running. To exercise Wi-Fi reconnection locally, use:

```bash
WIFI_CONNECTION_NAME='<connection-name>' ./restart-wifi.sh
```

The SSH connection will drop during that test.

## Graphics options

The installed GPU is AMD Renoir/Vega `[1002:1636]`. Its correct kernel driver
is `amdgpu`, with Mesa/RadeonSI providing hardware OpenGL. `vulkan-radeon`
provides RADV for Vulkan and is not an alternative OpenGL driver for AXIS.
There is no useful replacement kernel driver for this GPU; the old `radeon`
driver does not support Renoir.

Selecting every open-source graphics option in the installer does not make
all of those drivers active: PCI matching and Mesa select the driver for the
actual GPU. The installed `xf86-video-amdgpu` package is an optional Xorg DDX
and is not used by the current Wayland session; `mesa` remains the relevant
OpenGL package.

If AXIS crashes in the current Wayland/XWayland session, first retry with
Mesa's LLVMpipe software rendering:

```bash
LIBGL_ALWAYS_SOFTWARE=1 "$HOME/linuxcnc/config/start-linuxcnc.sh" \
    "$HOME/linuxcnc/mesa-7i95t-benchmark/mesa-7i95t-bench-1ms.ini"
```

Software rendering is a diagnostic fallback and may increase latency. Another
worthwhile comparison is an Xorg desktop session using Xorg's built-in
`modesetting` driver instead of the optional `xf86-video-amdgpu` DDX; neither
choice replaces the `amdgpu` kernel driver. Zink (OpenGL over RADV/Vulkan) is
another experimental diagnostic path, not the recommended LinuxCNC setup.

## Interpret the result

Run the watcher as the same desktop user that launched LinuxCNC.

Packet totals should remain zero, Boolean error flags should remain `FALSE`,
and the servo maximum must remain below its `1,000,000 ns` period with useful
margin. This is a regression test, not proof that a completed machine is safe.
