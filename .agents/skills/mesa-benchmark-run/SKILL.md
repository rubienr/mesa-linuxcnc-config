---
name: mesa-benchmark-run
description: Run or assess this repository's communication-only Mesa 7I95T benchmark, including affinity checks, load generation, live counters, and a concise result report. Use for benchmark execution or diagnosis, not Frida machine commissioning.
---

# Mesa benchmark run

Read `mesa-7i95t-benchmark/AGENTS.md` and its `README.md` before acting.

For a new benchmark run, confirm that hazardous machine outputs are
disconnected or unpowered and that no LinuxCNC/HAL realtime session is already
active. For assessment of an existing run, identify the active profile and
remain read-only unless the user explicitly requests a state change. Do not
flash firmware, enable outputs, or substitute the Frida commissioning profile.

The local checkout is for editing. After local changes, synchronize with the
repository's required `./tools/sync-to-target.sh` wrapper; use `--dry-run` when a
preview is useful. Never replace the wrapper with ad hoc `rsync`, and never add
deletion behavior. Execute target validation over SSH from `~/linuxcnc`; local
execution is not a benchmark result.

For a new run, use the repository scripts for the workflow:

1. Have the user or administrator apply network IRQ affinity with
   `config/thread-affinity-set.sh` when root authority is required.
2. Launch the explicitly requested benchmark INI through
   `config/linuxcnc-start.sh`; default to the documented 1 ms profile only when
   the user has not requested the 2 ms comparison.
3. Have the user or administrator reapply affinity after the servo thread
   exists, then check it with `config/thread-affinity-check.sh`.
4. Start `mesa-7i95t-benchmark/stress-test-start.sh` only when sustained load is
   part of the requested run.
5. Display or capture results with
   `mesa-7i95t-benchmark/counters-watch.sh`. Use `--once` for a snapshot.

For intermittent-error assessment:

- Use `counters-watch.sh --once` for a current snapshot.
- Use `diagnostics-monitor.sh` for a timestamped baseline, periodic heartbeats,
  and event records. Its default mode is read-only.
- Treat `--reset-tmax-after-event` as a diagnostic-state mutation and use it
  only when explicitly requested.
- Do not stop or restart an active monitor unless explicitly requested. When
  requested, use `diagnostics-stop.sh` so the monitor records shutdown and
  releases its instance lock cleanly.
- When the user explicitly requests a fresh run, use `diagnostics-restart.sh`
  to stop gracefully, archive the previous log directory, and start the new
  monitor. Do not invoke it merely to inspect existing evidence.
- Correlate event timestamps and baseline-relative deltas with timer, service,
  IRQ, NIC, and workload activity. One-second sampling can miss transient flags;
  cumulative totals and timing maxima are the durable triggers.

For multi-day log investigation, start with `diagnostics-report.sh --summary`,
then select `--events packet_error`. Inspect the complete event record and the
preceding heartbeat or event only when the compact timeline shows a relevant
change. Compare packet-total deltas with HostMot2 and servo maxima, NIC
error/drop deltas, sample lateness, IRQ counts and placement, realtime-task CPU,
load/pressure, and nearby kernel messages. Search narrow timestamp windows for
timer or service activity; do not ingest or print the complete multi-day log by
default. State observed facts separately from correlations and suspected
causes.

`counters-reset.sh --timing-maxima` intentionally mutates diagnostic timing
state. Use it only when explicitly requested. It never resets communication
error totals, flags, or safety-related state.

Report the profile, test duration and load, packet-error total and flags,
HostMot2 read/write maxima, servo-thread maximum and period, CPU/IRQ placement,
the synchronized revision or diff, monitor baseline and relevant event times
when available, and any deviation from the documented procedure. Zero packet
flags and timing below the period are necessary regression criteria, not proof
of machine safety.
