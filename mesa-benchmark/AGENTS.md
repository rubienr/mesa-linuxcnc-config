# Benchmark instructions

These rules apply to the communication-only Mesa 7I95T benchmark.

- Preserve both the 1 ms primary profile and 2 ms comparison profile.
- Keep all six step-generator enables and all six isolated SSR outputs false.
- Do not add motion, output control, firmware flashing, or machine commissioning
  behavior without an explicit request and safety review.
- Do not run validation while another LinuxCNC/HAL realtime session is active.
- Synchronize local changes to `frida@frida:~/linuxcnc/` and run the
  benchmark and its repository scripts on `frida`, not this workstation.
- After script changes, run `bash -n` and `shellcheck` when available.
- Keep `README.md`, profile names, scripts, and displayed counter names aligned.
- For multi-day logs, use `diagnostics-report.sh` to select run summaries and
  relevant events before reading complete rich snapshots. Do not dump entire
  logs when a targeted extract answers the diagnostic question.
- Prefer `--investigation-bundle --max-lines 200`, then extract one
  session-qualified record with only the necessary `--sections`. Run filtering
  on `frida` so raw multi-day logs remain on the target.
