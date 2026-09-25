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
sudo "$HOME/linuxcnc/config/thread-affinity-set.sh"
RTAPI_CPU_NUMBER=11 LIBGL_ALWAYS_SOFTWARE=0 \
    "$HOME/linuxcnc/config/linuxcnc-start.sh" \
    "$HOME/linuxcnc/mesa-benchmark/mesa-7i95t-bench-1ms.ini"
```

After LinuxCNC creates its realtime thread, verify that RTAPI created it on CPU
11. No second privileged setter call is normally required:

```bash
"$HOME/linuxcnc/config/thread-affinity-check.sh"
```

Start the reproducible CPU/memory load in another terminal. It excludes the
LinuxCNC and Mesa physical cores:

```bash
./stress-test-start.sh
```

To replace an existing graphics load with ten `glxgears` instances whose
entire process tree has enforced CPU affinity, run:

```bash
./glxgears-restart.sh
```

Stop only the managed graphics load with:

```bash
./glxgears-stop.sh
```

The script sends `SIGTERM` to existing `glxgears` processes, waits for them to
exit without escalating to `SIGKILL`, and starts the replacements in the user
service `mesa-glxgears-stress.service`. The service applies CPU affinity
`0-1,3-4,6-7,9-10`. A process-local preload shim intersects affinity changes
requested by Mesa renderer workers with that safe starting mask, preventing
them from moving onto CPUs 2, 5, 8, or 11 without making Mesa's affinity call
fail. The script builds the shim privately below `diagnostic-logs/` when its
tracked source changes. It remains attached while the graphics load is
running. The stop helper uses the managed user service and reports unrelated
instances without killing them.

The target user hierarchy does not have the cgroup `cpuset` controller
delegated, so a user scope with `AllowedCPUs=` records the requested property
but does not enforce it on this host. The service affinity and preload shim are
used instead. Building the shim requires the C compiler installed on `frida`.

Override the defaults with `GLXGEARS_CPUSET`, `GLXGEARS_INSTANCES`,
`GLXGEARS_NICE`, `GLXGEARS_SERVICE_UNIT`, or `GLXGEARS_STOP_TIMEOUT`. This
script does not start, stop, or modify LinuxCNC, HAL, the diagnostic monitor,
or machine outputs.

Watch all benchmark-relevant HostMot2 error flags, read/write maxima, and the
servo-thread row in one display:

```bash
./counters-watch.sh
```

It refreshes once per second. Set `WATCH_INTERVAL` to another positive interval
or use `./counters-watch.sh --once` for a scriptable snapshot.

## Record intermittent communication errors

Use the diagnostic monitor to establish a counter baseline and append rich
snapshots when communication counters, timing maxima, NIC errors, affinity, or
the monitored workload changes:

```bash
./diagnostics-monitor.sh
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
./diagnostics-monitor.sh \
    --output mesa-long-run.log \
    --heartbeat 600

# Diagnostic-state mutation: reset only writable timing maxima after an event.
./diagnostics-monitor.sh --reset-tmax-after-event

# Safe short test: no HAL or network access, including a simulated failure.
./diagnostics-monitor.sh --mock --interval 0.1 --heartbeat 0.2 --max-samples 5
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
./diagnostics-stop.sh
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

For a compact summary or event timeline without printing the rich snapshots,
use the read-only report helper:

```bash
./diagnostics-report.sh --summary diagnostic-logs/mesa-long-run.log
./diagnostics-report.sh --packet-errors \
    diagnostic-logs/mesa-long-run.log
./diagnostics-report.sh --around '2026-09-24T14:31' \
    diagnostic-logs/mesa-long-run.log
./diagnostics-report.sh --timeline --format tsv \
    diagnostic-logs/mesa-long-run.log
./diagnostics-report.sh --investigation-bundle --max-lines 200 \
    diagnostic-logs/mesa-long-run.log
./diagnostics-report.sh --record '<SESSION_ID>:<SEQUENCE>' \
    --sections core,values,deltas,irq_details,realtime_task,kernel_messages \
    diagnostic-logs/mesa-long-run.log
```

Without an explicit log path, it reads the newest primary `.log` in
`diagnostic-logs/`. Reports include only complete records. `--around` accepts a
record sequence or timestamp substring and includes the adjacent records;
`--since` accepts an ISO-8601 timestamp from the same host/timezone convention.
`--investigation-bundle` emits a bounded summary plus each packet-error event
and its compact neighbors. After selecting an event, `--record` extracts only
the requested rich sections. A bare sequence is accepted only when it uniquely
identifies one complete record across the supplied logs; otherwise include the
session ID shown in timeline output. Avoid `--sections all` unless the complete
selected record is genuinely necessary.

To begin a clean diagnostic run while preserving the current run, use:

```bash
./diagnostics-restart.sh -- --output mesa-long-run.log --heartbeat 600
```

The helper gracefully stops the active monitor, moves `diagnostic-logs/` to a
UTC timestamped sibling, recreates the private log directory, starts the new
monitor under `nohup`, and verifies its lock. It does not restart LinuxCNC or
HAL. If graceful shutdown fails, it leaves the existing log directory in
place.

To explicitly reset only the writable timing maxima while LinuxCNC is running:

```bash
./counters-reset.sh --timing-maxima
```

This changes diagnostic state and can make later intervals easier to
correlate. It prints before/after values and never resets packet-error totals,
error flags, or safety state.

One-second polling cannot reliably observe millisecond-wide Boolean error
flags. The cumulative packet-error total and monotonic timing maxima are the
durable triggers; transient flags are recorded whenever a sample sees them.

The optional communication-only check is `halrun validate-7i95t.hal` when no
other HAL session is running. To exercise Wi-Fi reconnection locally, use:

```bash
WIFI_CONNECTION_NAME='<connection-name>' ./wifi-restart.sh
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
RTAPI_CPU_NUMBER=11 LIBGL_ALWAYS_SOFTWARE=1 \
    "$HOME/linuxcnc/config/linuxcnc-start.sh" \
    "$HOME/linuxcnc/mesa-benchmark/mesa-7i95t-bench-1ms.ini"
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
