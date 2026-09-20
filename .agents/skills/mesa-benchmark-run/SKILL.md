---
name: mesa-benchmark-run
description: Run or assess this repository's communication-only Mesa 7I95T benchmark, including affinity checks, load generation, live counters, and a concise result report. Use for benchmark execution or diagnosis, not Frida machine commissioning.
---

# Mesa benchmark run

Read `mesa-7i95t-benchmark/AGENTS.md` and its `README.md` before acting.

Confirm that hazardous machine outputs are disconnected or unpowered and that
no other LinuxCNC/HAL realtime session is active. Do not flash firmware, enable
outputs, or substitute the Frida commissioning profile.

The local checkout is for editing. Before any run, synchronize the intended
changes with `rsync` to `frida@frida:/home/frida/linuxcnc/`, preserving relative
paths and excluding `.git`. Do not use `--delete` without explicit approval.
Execute every workflow command over SSH from `/home/frida/linuxcnc`; local
execution is not a benchmark result.

Use the repository scripts for the workflow:

1. On `frida`, apply network IRQ affinity with
   `config/set-thread-affinity.sh`.
2. Launch the explicitly requested benchmark INI through
   `config/start-linuxcnc.sh`; default to the documented 1 ms profile only when
   the user has not requested the 2 ms comparison.
3. Reapply and check affinity after the servo thread exists.
4. Start `mesa-7i95t-benchmark/start-stress-test.sh` only when sustained load is
   part of the requested run.
5. Display or capture results with
   `mesa-7i95t-benchmark/watch-counters.sh`. Use `--once` for a snapshot.

Report the profile, test duration and load, packet-error total and flags,
HostMot2 read/write maxima, servo-thread maximum and period, CPU/IRQ placement,
the synchronized revision or diff, and any deviation from the documented
procedure. Zero packet flags and timing below the period are necessary
regression criteria, not proof of machine safety.
