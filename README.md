# LinuxCNC workspace

This repository records the reproducible LinuxCNC setup for the Lenovo
ThinkCentre M75q Gen 2 and its Ethernet-connected Mesa 7I95T. It keeps
operating scripts, benchmark configurations, and the Arch Linux installation
notes in one place.

## Directories

- [`archlinux/`](archlinux/) documents installation of LinuxCNC on Arch with
  PREEMPT_RT, the patched BLT build, the `r8168-dkms` driver, kernel tuning,
  and the BIOS settings used on this host.
- [`config/`](config/) contains the normal operator scripts: apply and check
  CPU/IRQ affinity, and launch LinuxCNC with selectable hardware or software
  OpenGL rendering.
- [`mesa-7i95t-benchmark/`](mesa-7i95t-benchmark/) is a 1 ms and 2 ms HostMot2
  Ethernet benchmark with outputs commanded off, plus its repeatable load
  generator. It must not be treated as a machine-control configuration.

Start with the README in the relevant directory. AI coding agents should also
read [`AGENTS.md`](AGENTS.md) before changing this workspace.
