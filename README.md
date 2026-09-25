# LinuxCNC workspace

This repository records the LinuxCNC host, runtime tooling, Mesa communication
benchmark, current machine evidence, and the staged Frida migration from the
BeagleBone/Panther controller to a Mesa 7I95T.

## Project map

| Area | Purpose | Status |
| --- | --- | --- |
| [`archlinux/`](archlinux/) | Arch Linux, PREEMPT_RT, driver, BIOS, and CPU-isolation setup | Host installation record |
| [`config/`](config/) | Affinity and launcher scripts plus `config/frida-mesa/` | Runtime tooling and unverified commissioning profile |
| [`mesa-benchmark/`](mesa-benchmark/) | Repeatable 1 ms/2 ms HostMot2 Ethernet test | Communication-only; not machine control |
| [`hardware-documentation/current/`](hardware-documentation/current/) | Verified hardware, recovered settings, migration evidence, and open work | Current documentation source of truth |
| [`hardware-documentation/legacy/`](hardware-documentation/legacy/) | BBB/Panther schematics and Machinekit configuration | Forensic evidence only |

## Source-of-truth boundaries

- Host installation and tuning rationale: `archlinux/README.md`.
- Runtime CPU/IRQ enforcement: scripts under `config/`.
- Frida LinuxCNC behavior and proposed terminal allocation:
  `config/frida-mesa/` and its `wiring.csv`.
- Current physical-machine facts: topic documents under
  `hardware-documentation/current/`.
- Historical files under `hardware-documentation/legacy/` must be verified
  before their values are reused.

Start with the README in the relevant area. AI coding agents must follow the
root and nearest scoped `AGENTS.md` files before changing this workspace.

## Synchronizing to the target

After making local changes, synchronize the complete workspace to the target
checkout before target-host testing:

```console
./tools/sync-to-target.sh
```

Use `./tools/sync-to-target.sh --dry-run` to preview changes. The wrapper
transfers the workspace to `frida@frida:~/linuxcnc/` over SSH,
excludes `.git`, and does not delete files that exist only on the target.
`TARGET_SSH_DESTINATION` and `TARGET_WORKSPACE` provide explicit overrides when
needed. Generated diagnostic logs, monitor locks, and archived diagnostic runs
remain target-local; only the tracked log-directory placeholders are copied.

## Convenience launchers

From the repository root, `./linuxcnc-start.sh /path/to/config.ini` forwards an
explicit INI to `config/linuxcnc-start.sh` after interactively applying and
checking IRQ affinity. LinuxCNC RTAPI creates its realtime task on CPU 11 via
`RTAPI_CPU_NUMBER`; a second unprivileged check is logged after the task
appears. To launch the communication-only 1 ms Mesa profile in a detached
screen session, use:

```console
./linuxcnc-benchmark-mesa-1ms.sh
screen -r mesa-benchmark-1ms
```

The benchmark launcher refuses to run when it detects an existing LinuxCNC,
LinuxCNC server, or RTAPI process. Override only the screen session name with
`MESA_SCREEN_SESSION`. Affinity logs are written privately below
`mesa-benchmark/diagnostic-logs/`. A failed pre-start affinity check is logged
as a warning and does not prevent startup because the LinuxCNC realtime task
does not exist yet. A setter failure remains fatal, and the delayed post-start
check records the authoritative realtime-task placement.

Run the affinity tools directly from the repository root with:

```console
./thread-affinity-check.sh --brief
./thread-affinity-set.sh
```

These convenience scripts delegate all arguments to their counterparts below
`config/`; the root setter invokes `sudo` and therefore retains its interactive
password prompt.

Manage the graphics stress load and show a concise runtime overview from the
repository root with:

```console
./glxgears-restart.sh
./glxgears-stop.sh
./runtime-status.sh
```

The stop helper stops only the managed `mesa-glxgears-stress.service` and
reports unrelated surviving `glxgears` processes instead of killing them.
