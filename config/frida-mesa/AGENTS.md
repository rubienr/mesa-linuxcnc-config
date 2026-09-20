# Frida commissioning-profile instructions

These rules apply to the unverified Frida machine configuration.

- Treat `wiring.csv` as the proposed terminal-allocation source of truth. Keep
  it, the INI, HAL files, and current hardware documentation consistent.
- Preserve the six unassigned SSR outputs and three unused step generators as
  disabled. Do not assign or enable hazardous outputs without explicit scope,
  physical verification, and a safety review.
- Do not enable the legacy probing/tool-change macros until their coordinates,
  input polarity, abort behavior, and safe-power test results are documented.
- Mark recovered values as legacy-derived until physically verified. Never
  infer wire identity, voltage domain, or safety behavior from the old
  schematic alone.
- Validate configuration references and HAL syntax when the needed LinuxCNC
  tools are available on `frida`, after synchronizing local changes to
  `/home/frida/linuxcnc`. Never start this profile alongside another realtime
  session.
