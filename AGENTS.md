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
- `mesa-benchmark/`: communication-only HostMot2 Ethernet benchmark. Read
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
  `~/linuxcnc`.
- Refer to paths below the target user's home with `~/...`; do not spell out
  that user's absolute home directory in scripts, documentation, examples, or
  agent skills unless an external interface explicitly requires an absolute
  path.
- The `frida` account has no sudo rights. Do not assume privileged access or
  repeatedly retry privileged diagnostics. Record unavailable evidence and
  hand actions requiring root authority back to the user or administrator.
- After changing files locally, run `./tools/sync-to-target.sh` before testing
  them on the target. Use `./tools/sync-to-target.sh --dry-run` when a preview is
  useful. This
  is the default and required workspace-sync method for agents; do not replace
  it with an ad hoc `rsync` command. The wrapper preserves repository-relative
  paths, excludes `.git` and generated diagnostic data, and never deletes
  remote files.
- Run repository scripts and LinuxCNC/HAL commands on `frida`, normally through
  `ssh frida@frida 'cd ~/linuxcnc && ...'`; do not treat local script
  execution as target-host validation.

If an applicable `AGENTS.md`, skill, or documented workflow appears outdated,
misleading, contradictory, incomplete, or in need of refactoring, tell the
user. Identify the affected file, explain the problem, and propose a correction
instead of silently working around it.

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
