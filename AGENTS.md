# AGENTS.md

These instructions apply to the whole repository.

## Read first

Read the root `README.md` and the nearest directory `README.md` before editing
files. Keep documentation and scripts consistent whenever paths, CPU
assignments, interfaces, addresses, or LinuxCNC configuration names change.

## Host assumptions

- Host: Lenovo ThinkCentre M75q Gen 2, Ryzen 5 PRO 4650GE, 12 logical CPUs.
- Realtime CPUs: CPU 11 for the LinuxCNC servo thread; CPU 5 is its idle SMT
  sibling.
- Mesa network CPUs: CPU 8 for the `enp1s0` IRQ; CPU 2 is its idle SMT sibling.
- Dedicated Mesa network: `enp1s0` at `192.168.1.111/24`; 7I95T at
  `192.168.1.121`.
- Wi-Fi/SSH: `wlp2s0`; do not disable it or place its IRQs on CPUs 2, 5, 8, or
  11.

IRQ numbers are not stable across boots. Always discover them through
`/sys/class/net/INTERFACE/device/msi_irqs`; never hard-code IRQ numbers.

## Safety and validation

The benchmark is communication-only. Do not add output enables, flash the
7I95T, or turn the benchmark into a machine-control configuration without an
explicit request and a safety review. The current benchmark holds all six
stepgen enables and all six isolated SSR outputs false, but software state is
not a safety function. Do not run it with drives, a spindle, or field outputs
energized.

Use Bash strict mode in new shell scripts, quote expansions, and make scripts
configurable through clearly named environment variables. Validate shell
syntax with `bash -n`; use `shellcheck` when available. Do not start a second
LinuxCNC/HAL realtime session while another one is active.
