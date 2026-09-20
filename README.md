# LinuxCNC workspace

This repository records the LinuxCNC host, runtime tooling, Mesa communication
benchmark, current machine evidence, and the staged Frida migration from the
BeagleBone/Panther controller to a Mesa 7I95T.

## Project map

| Area | Purpose | Status |
| --- | --- | --- |
| [`archlinux/`](archlinux/) | Arch Linux, PREEMPT_RT, driver, BIOS, and CPU-isolation setup | Host installation record |
| [`config/`](config/) | Affinity and launcher scripts plus `config/frida-mesa/` | Runtime tooling and unverified commissioning profile |
| [`mesa-7i95t-benchmark/`](mesa-7i95t-benchmark/) | Repeatable 1 ms/2 ms HostMot2 Ethernet test | Communication-only; not machine control |
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
