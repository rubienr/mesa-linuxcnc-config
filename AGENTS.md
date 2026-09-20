# AGENTS.md

These instructions apply to the whole repository. Before editing a subtree,
check for and read its nearest `AGENTS.md`; scoped instructions supplement this
file. Read only the task-specific documentation named below rather than scanning
all READMEs, legacy files, datasheets, or generated records.

## Project map and routing

- `archlinux/`: Arch Linux, PREEMPT_RT, drivers, BIOS, and CPU isolation. Read
  `archlinux/README.md` for host provisioning or tuning work.
- `config/`: shared affinity/launcher scripts and the commissioning profile in
  `config/frida-mesa/`. Read `config/README.md` for runtime or machine-config
  work, then `config/frida-mesa/AGENTS.md` when touching that profile.
- `mesa-7i95t-benchmark/`: communication-only HostMot2 Ethernet benchmark. Read
  its README and scoped instructions for benchmark work.
- `hardware-documentation/current/`: current hardware evidence, organized by
  topic. Start with its README index and open only the relevant topic file.
- `hardware-documentation/legacy/`: forensic BBB/Panther/Machinekit evidence.
  It is not authoritative for the current machine.

Keep documentation and scripts consistent whenever paths, CPU assignments,
interfaces, addresses, wiring allocations, or LinuxCNC configuration names
change.

## Workstation and target host

- This checkout is the editing workspace. Prompts and file changes happen on
  this workstation; LinuxCNC runs on the target host `frida`.
- Access the target as `frida@frida`. Its checkout of this same repository is
  `/home/frida/linuxcnc`.
- After changing files locally, synchronize the intended working-tree files to
  that checkout with `rsync` over SSH before testing them. Preserve repository-
  relative paths, exclude `.git`, and do not use `--delete` unless the user
  explicitly requests deletion of confirmed remote paths.
- Run repository scripts and LinuxCNC/HAL commands on `frida`, normally through
  `ssh frida@frida 'cd /home/frida/linuxcnc && ...'`; do not treat local script
  execution as target-host validation.

## Host invariants

- Host: Lenovo ThinkCentre M75q Gen 2, Ryzen 5 PRO 4650GE, 12 logical CPUs.
- LinuxCNC servo thread: CPU 11; keep its SMT sibling CPU 5 idle.
- Mesa `enp1s0` IRQ: CPU 8; keep its SMT sibling CPU 2 idle.
- Mesa LAN: `enp1s0` at `192.168.1.111/24`; 7I95T at `192.168.1.121`.
- Wi-Fi/SSH: `wlp2s0`; never disable it or place its IRQs on CPUs 2, 5, 8, or
  11.

IRQ numbers change across boots. Discover them through
`/sys/class/net/INTERFACE/device/msi_irqs`; never hard-code IRQ numbers.

## Safety and validation

The benchmark is communication-only. Do not add output enables, flash the
7I95T, or turn it into a machine-control configuration without an explicit
request and safety review. The Frida profile is an unverified commissioning
configuration; software state is not a safety function. Do not test either
configuration with hazardous actuator power enabled.

Use Bash strict mode in new shell scripts, quote expansions, and expose
configuration through clearly named environment variables. Validate shell
syntax with `bash -n` and use `shellcheck` when available. Do not start a second
LinuxCNC/HAL realtime session while another one is active.

## Before commit: redaction review

- Review the complete pending diff, including untracked files, for secrets,
  credentials, private keys, tokens, passwords, personal data, usernames,
  absolute home paths, hostnames, device serials, and nonessential network
  details.
- Redact nonessential sensitive values from documentation and examples. Prefer
  placeholders such as `<USER>`, `<HOST>`, `<HOME>`, and `<DEVICE>` when the
  literal value is not required to operate or diagnose this installation.
- Configuration may legitimately require concrete hosts, paths, addresses, and
  device identifiers. Do not silently redact values that would break it;
  identify them to the user before commit and explain why they appear necessary.
- Never commit an actual secret. Stop and alert the user if one is found, and
  consider whether it must also be removed from Git history or rotated.
